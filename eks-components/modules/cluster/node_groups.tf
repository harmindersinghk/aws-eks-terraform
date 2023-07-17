locals {
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # EKS managed node group
  default_update_config = {
    max_unavailable_percentage = 25
  }

  # Self-managed node group
  default_instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 66
    }
  }
}

# This sleep resource is used to provide a timed gap between the cluster creation and the downstream dependencies
# that consume the outputs from here. Any of the values that are used as triggers can be used in dependencies
# to ensure that the downstream resources are created after both the cluster is ready and the sleep time has passed.
# This was primarily added to give addons that need to be configured BEFORE data plane compute resources
# enough time to create and configure themselves before the data plane compute resources are created.
resource "time_sleep" "this" {
  count = var.create ? 1 : 0

  create_duration = var.dataplane_wait_duration

  triggers = {
    cluster_name     = aws_eks_cluster.this[0].name
    cluster_endpoint = aws_eks_cluster.this[0].endpoint
    cluster_version  = aws_eks_cluster.this[0].version

    cluster_certificate_authority_data = aws_eks_cluster.this[0].certificate_authority[0].data
  }
}

################################################################################
# EKS IPV6 CNI Policy
# TODO - hopefully AWS releases a managed policy which can replace this
# https://docs.aws.amazon.com/eks/latest/userguide/cni-iam-role.html#cni-iam-role-create-ipv6-policy
################################################################################

data "aws_iam_policy_document" "cni_ipv6_policy" {
  count = var.create && var.create_cni_ipv6_iam_policy ? 1 : 0

  statement {
    sid = "AssignDescribe"
    actions = [
      "ec2:AssignIpv6Addresses",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "CreateTags"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:${data.aws_partition.current.partition}:ec2:*:*:network-interface/*"]
  }
}

# Note - we are keeping this to a minimum in hopes that its soon replaced with an AWS managed policy like `AmazonEKS_CNI_Policy`
resource "aws_iam_policy" "cni_ipv6_policy" {
  count = var.create && var.create_cni_ipv6_iam_policy ? 1 : 0

  # Will cause conflicts if trying to create on multiple clusters but necessary to reference by exact name in sub-modules
  name        = "AmazonEKS_CNI_IPv6_Policy"
  description = "IAM policy for EKS CNI to assign IPV6 addresses"
  policy      = data.aws_iam_policy_document.cni_ipv6_policy[0].json

  tags = var.tags
}

################################################################################
# Node Security Group
# Defaults follow https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
# Plus NTP/HTTPS (otherwise nodes fail to launch)
################################################################################

locals {
  node_sg_name   = coalesce(var.node_security_group_name, "${var.cluster_name}-node")
  create_node_sg = var.create && var.create_node_security_group

  node_security_group_id = local.create_node_sg ? aws_security_group.node[0].id : var.node_security_group_id

  node_security_group_rules = {
    ingress_cluster_443 = {
      description                   = "Cluster API to node groups"
      protocol                      = "tcp"
      from_port                     = 443
      to_port                       = 443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_cluster_kubelet = {
      description                   = "Cluster API to node kubelets"
      protocol                      = "tcp"
      from_port                     = 10250
      to_port                       = 10250
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_self_coredns_tcp = {
      description = "Node to node CoreDNS"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    }
    ingress_self_coredns_udp = {
      description = "Node to node CoreDNS UDP"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    }
  }

  node_security_group_recommended_rules = { for k, v in {
    ingress_nodes_ephemeral = {
      description = "Node to node ingress on ephemeral ports"
      protocol    = "tcp"
      from_port   = 1025
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
    # metrics-server
    ingress_cluster_4443_webhook = {
      description                   = "Cluster API to node 4443/tcp webhook"
      protocol                      = "tcp"
      from_port                     = 4443
      to_port                       = 4443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    # prometheus-adapter
    ingress_cluster_6443_webhook = {
      description                   = "Cluster API to node 6443/tcp webhook"
      protocol                      = "tcp"
      from_port                     = 6443
      to_port                       = 6443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    # Karpenter
    ingress_cluster_8443_webhook = {
      description                   = "Cluster API to node 8443/tcp webhook"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    # ALB controller, NGINX
    ingress_cluster_9443_webhook = {
      description                   = "Cluster API to node 9443/tcp webhook"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Allow all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = var.cluster_ip_family == "ipv6" ? ["::/0"] : null
    }
  } : k => v if var.node_security_group_enable_recommended_rules }
}

resource "aws_security_group" "node" {
  count = local.create_node_sg ? 1 : 0

  name        = var.node_security_group_use_name_prefix ? null : local.node_sg_name
  name_prefix = var.node_security_group_use_name_prefix ? "${local.node_sg_name}${var.prefix_separator}" : null
  description = var.node_security_group_description
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      "Name"                                      = local.node_sg_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
    var.node_security_group_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "node" {
  for_each = { for k, v in merge(
    local.node_security_group_rules,
    local.node_security_group_recommended_rules,
    var.node_security_group_additional_rules,
  ) : k => v if local.create_node_sg }

  # Required
  security_group_id = aws_security_group.node[0].id
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type

  # Optional
  description              = lookup(each.value, "description", null)
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks         = lookup(each.value, "ipv6_cidr_blocks", null)
  prefix_list_ids          = lookup(each.value, "prefix_list_ids", [])
  self                     = lookup(each.value, "self", null)
  source_security_group_id = try(each.value.source_cluster_security_group, false) ? local.cluster_security_group_id : lookup(each.value, "source_security_group_id", null)
}


################################################################################
# EKS Managed Node Group
################################################################################

module "eks_managed_node_group" {
  source = "../eks-managed-node-group"

  for_each = { for k, v in var.eks_managed_node_groups : k => v if var.create && !local.create_outposts_local_cluster }

  create = try(each.value.create, true)

  cluster_name      = time_sleep.this[0].triggers["cluster_name"]
  cluster_version   = try(each.value.cluster_version, var.eks_managed_node_group_defaults.cluster_version, time_sleep.this[0].triggers["cluster_version"])
  cluster_ip_family = var.cluster_ip_family

  # EKS Managed Node Group
  name            = try(each.value.name, each.key)
  use_name_prefix = try(each.value.use_name_prefix, var.eks_managed_node_group_defaults.use_name_prefix, true)

  subnet_ids = try(each.value.subnet_ids, var.eks_managed_node_group_defaults.subnet_ids, var.subnet_ids)

  min_size     = try(each.value.min_size, var.eks_managed_node_group_defaults.min_size, 1)
  max_size     = try(each.value.max_size, var.eks_managed_node_group_defaults.max_size, 4)
  desired_size = try(each.value.desired_size, var.eks_managed_node_group_defaults.desired_size, 1)

  ami_id              = try(each.value.ami_id, var.eks_managed_node_group_defaults.ami_id, "")
  ami_type            = try(each.value.ami_type, var.eks_managed_node_group_defaults.ami_type, null)
  ami_release_version = try(each.value.ami_release_version, var.eks_managed_node_group_defaults.ami_release_version, null)

  capacity_type        = try(each.value.capacity_type, var.eks_managed_node_group_defaults.capacity_type, null)
  disk_size            = try(each.value.disk_size, var.eks_managed_node_group_defaults.disk_size, null)
  force_update_version = try(each.value.force_update_version, var.eks_managed_node_group_defaults.force_update_version, null)
  instance_types       = try(each.value.instance_types, var.eks_managed_node_group_defaults.instance_types, null)
  labels               = try(each.value.labels, var.eks_managed_node_group_defaults.labels, null)

  remote_access = try(each.value.remote_access, var.eks_managed_node_group_defaults.remote_access, {})
  taints        = try(each.value.taints, var.eks_managed_node_group_defaults.taints, {})
  update_config = try(each.value.update_config, var.eks_managed_node_group_defaults.update_config, local.default_update_config)
  timeouts      = try(each.value.timeouts, var.eks_managed_node_group_defaults.timeouts, {})

  # User data
  platform                   = try(each.value.platform, var.eks_managed_node_group_defaults.platform, "linux")
  cluster_endpoint           = try(time_sleep.this[0].triggers["cluster_endpoint"], "")
  cluster_auth_base64        = try(time_sleep.this[0].triggers["cluster_certificate_authority_data"], "")
  cluster_service_ipv4_cidr  = var.cluster_service_ipv4_cidr
  enable_bootstrap_user_data = try(each.value.enable_bootstrap_user_data, var.eks_managed_node_group_defaults.enable_bootstrap_user_data, false)
  pre_bootstrap_user_data    = try(each.value.pre_bootstrap_user_data, var.eks_managed_node_group_defaults.pre_bootstrap_user_data, "")
  post_bootstrap_user_data   = try(each.value.post_bootstrap_user_data, var.eks_managed_node_group_defaults.post_bootstrap_user_data, "")
  bootstrap_extra_args       = try(each.value.bootstrap_extra_args, var.eks_managed_node_group_defaults.bootstrap_extra_args, "")
  user_data_template_path    = try(each.value.user_data_template_path, var.eks_managed_node_group_defaults.user_data_template_path, "")

  # Launch Template
  create_launch_template                 = try(each.value.create_launch_template, var.eks_managed_node_group_defaults.create_launch_template, true)
  use_custom_launch_template             = try(each.value.use_custom_launch_template, var.eks_managed_node_group_defaults.use_custom_launch_template, true)
  launch_template_id                     = try(each.value.launch_template_id, var.eks_managed_node_group_defaults.launch_template_id, "")
  launch_template_name                   = try(each.value.launch_template_name, var.eks_managed_node_group_defaults.launch_template_name, each.key)
  launch_template_use_name_prefix        = try(each.value.launch_template_use_name_prefix, var.eks_managed_node_group_defaults.launch_template_use_name_prefix, true)
  launch_template_version                = try(each.value.launch_template_version, var.eks_managed_node_group_defaults.launch_template_version, null)
  launch_template_default_version        = try(each.value.launch_template_default_version, var.eks_managed_node_group_defaults.launch_template_default_version, null)
  update_launch_template_default_version = try(each.value.update_launch_template_default_version, var.eks_managed_node_group_defaults.update_launch_template_default_version, true)
  launch_template_description            = try(each.value.launch_template_description, var.eks_managed_node_group_defaults.launch_template_description, "Custom launch template for ${try(each.value.name, each.key)} EKS managed node group")
  launch_template_tags                   = try(each.value.launch_template_tags, var.eks_managed_node_group_defaults.launch_template_tags, {})
  tag_specifications                     = try(each.value.tag_specifications, var.eks_managed_node_group_defaults.tag_specifications, ["instance", "volume", "network-interface"])

  ebs_optimized           = try(each.value.ebs_optimized, var.eks_managed_node_group_defaults.ebs_optimized, null)
  key_name                = try(each.value.key_name, var.eks_managed_node_group_defaults.key_name, null)
  disable_api_termination = try(each.value.disable_api_termination, var.eks_managed_node_group_defaults.disable_api_termination, null)
  kernel_id               = try(each.value.kernel_id, var.eks_managed_node_group_defaults.kernel_id, null)
  ram_disk_id             = try(each.value.ram_disk_id, var.eks_managed_node_group_defaults.ram_disk_id, null)

  block_device_mappings              = try(each.value.block_device_mappings, var.eks_managed_node_group_defaults.block_device_mappings, {})
  capacity_reservation_specification = try(each.value.capacity_reservation_specification, var.eks_managed_node_group_defaults.capacity_reservation_specification, {})
  cpu_options                        = try(each.value.cpu_options, var.eks_managed_node_group_defaults.cpu_options, {})
  credit_specification               = try(each.value.credit_specification, var.eks_managed_node_group_defaults.credit_specification, {})
  elastic_gpu_specifications         = try(each.value.elastic_gpu_specifications, var.eks_managed_node_group_defaults.elastic_gpu_specifications, {})
  elastic_inference_accelerator      = try(each.value.elastic_inference_accelerator, var.eks_managed_node_group_defaults.elastic_inference_accelerator, {})
  enclave_options                    = try(each.value.enclave_options, var.eks_managed_node_group_defaults.enclave_options, {})
  instance_market_options            = try(each.value.instance_market_options, var.eks_managed_node_group_defaults.instance_market_options, {})
  license_specifications             = try(each.value.license_specifications, var.eks_managed_node_group_defaults.license_specifications, {})
  metadata_options                   = try(each.value.metadata_options, var.eks_managed_node_group_defaults.metadata_options, local.metadata_options)
  enable_monitoring                  = try(each.value.enable_monitoring, var.eks_managed_node_group_defaults.enable_monitoring, true)
  network_interfaces                 = try(each.value.network_interfaces, var.eks_managed_node_group_defaults.network_interfaces, [])
  placement                          = try(each.value.placement, var.eks_managed_node_group_defaults.placement, {})
  maintenance_options                = try(each.value.maintenance_options, var.eks_managed_node_group_defaults.maintenance_options, {})
  private_dns_name_options           = try(each.value.private_dns_name_options, var.eks_managed_node_group_defaults.private_dns_name_options, {})

  # IAM role
  create_iam_role               = try(each.value.create_iam_role, var.eks_managed_node_group_defaults.create_iam_role, true)
  iam_role_arn                  = try(each.value.iam_role_arn, var.eks_managed_node_group_defaults.iam_role_arn, null)
  iam_role_name                 = try(each.value.iam_role_name, var.eks_managed_node_group_defaults.iam_role_name, null)
  iam_role_use_name_prefix      = try(each.value.iam_role_use_name_prefix, var.eks_managed_node_group_defaults.iam_role_use_name_prefix, true)
  iam_role_path                 = try(each.value.iam_role_path, var.eks_managed_node_group_defaults.iam_role_path, null)
  iam_role_description          = try(each.value.iam_role_description, var.eks_managed_node_group_defaults.iam_role_description, "EKS managed node group IAM role")
  iam_role_permissions_boundary = try(each.value.iam_role_permissions_boundary, var.eks_managed_node_group_defaults.iam_role_permissions_boundary, null)
  iam_role_tags                 = try(each.value.iam_role_tags, var.eks_managed_node_group_defaults.iam_role_tags, {})
  iam_role_attach_cni_policy    = try(each.value.iam_role_attach_cni_policy, var.eks_managed_node_group_defaults.iam_role_attach_cni_policy, true)
  # To better understand why this `lookup()` logic is required, see:
  # https://github.com/hashicorp/terraform/issues/31646#issuecomment-1217279031
  iam_role_additional_policies = lookup(each.value, "iam_role_additional_policies", lookup(var.eks_managed_node_group_defaults, "iam_role_additional_policies", {}))

  create_schedule = try(each.value.create_schedule, var.eks_managed_node_group_defaults.create_schedule, true)
  schedules       = try(each.value.schedules, var.eks_managed_node_group_defaults.schedules, {})

  # Security group
  vpc_security_group_ids            = compact(concat([local.node_security_group_id], try(each.value.vpc_security_group_ids, var.eks_managed_node_group_defaults.vpc_security_group_ids, [])))
  cluster_primary_security_group_id = try(each.value.attach_cluster_primary_security_group, var.eks_managed_node_group_defaults.attach_cluster_primary_security_group, false) ? aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id : null

  tags = merge(var.tags, try(each.value.tags, var.eks_managed_node_group_defaults.tags, {}))
}

