provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_infra.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_infra.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks_infra.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_infra.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "bcrypt" {}

data "aws_eks_cluster" "eks_infra" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

data "aws_availability_zones" "available" {}

locals {
  # name   = basename(path.cwd)
  name   = "eks-cluster"
  region = "eu-west-1"

  cluster_version = "1.24"

  tags = {
    Blueprint = local.name
  }
}

################################################################################
# Kubernetes Addons
################################################################################

module "eks_blueprints_kubernetes_addons" {
  source = "../eks-components/modules//kubernetes-addons"

  eks_cluster_id       = data.aws_eks_cluster.eks_infra.id
  eks_cluster_endpoint = data.aws_eks_cluster.eks_infra.endpoint
  eks_oidc_provider    = data.aws_eks_cluster.eks_infra.identity[0].oidc[0].issuer
  eks_cluster_version  = data.aws_eks_cluster.eks_infra.version

  enable_argocd = var.enable_argocd 
  # This example shows how to set default ArgoCD Admin Password using SecretsManager with Helm Chart set_sensitive values.
  argocd_helm_config = {
    set_sensitive = [
      {
        name  = "configs.secret.argocdServerAdminPassword"
        value = bcrypt_hash.argo.id
      }
    ]
  }

  argocd_manage_add_ons = var.argocd_manage_add_ons # Indicates that ArgoCD is responsible for managing/deploying add-ons
  argocd_applications = {
    addons = {
      path               = "chart"
      repo_url           = "https://github.com/harmindersinghk/eks-blueprints-add-ons.git"
      target_revision    = "release-1-1"
      add_on_application = true
    }
    # workloads = {
    #   path               = "envs/dev"
    #   repo_url           = "https://github.com/aws-samples/eks-blueprints-workloads.git"
    #   add_on_application = false
    # }
  }

  # Add-ons
  enable_amazon_eks_aws_ebs_csi_driver = false
  enable_aws_for_fluentbit             = false
  # Let fluentbit create the cw log group
  aws_for_fluentbit_create_cw_log_group = false
  enable_calico                         = var.enable_calico
  enable_cert_manager                   = var.enable_cert_manager
  enable_cluster_autoscaler             = false
  enable_grafana                        = false
  enable_karpenter                      = false
  enable_keda                           = false
  enable_metrics_server                 = var.enable_metrics_server 
  enable_prometheus                     = false
  enable_traefik                        = false
  enable_vpa                            = false
  enable_yunikorn                       = false
  enable_argo_rollouts                  = false

  tags = local.tags
}

#---------------------------------------------------------------
# ArgoCD Admin Password credentials with Secrets Manager
# Login to AWS Secrets manager with the same role as Terraform to extract the ArgoCD admin password with the secret name as "argocd"
#---------------------------------------------------------------
resource "random_password" "argocd" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Argo requires the password to be bcrypt, we use custom provider of bcrypt,
# as the default bcrypt function generates diff for each terraform plan
resource "bcrypt_hash" "argo" {
  cleartext = random_password.argocd.result
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "argocd" {
  name                    = "argocd"
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

resource "aws_secretsmanager_secret_version" "argocd" {
  secret_id     = aws_secretsmanager_secret.argocd.id
  secret_string = random_password.argocd.result
}

output "eks_oidc_issuer_url" {
  description = "eks_oidc_issuer_url"
  value       = module.eks_blueprints_kubernetes_addons.karpenter
}