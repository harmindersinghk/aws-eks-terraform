locals {
  name   = "ex-iam-github-oidc"
  region = "eu-west-1"

  tags = {
    Name = local.name
  }
}

################################################################################
# GitHub OIDC Provider
# Note: This is one per AWS account
################################################################################

module "iam_github_oidc_provider" {
  source = "./modules/iam-github-oidc-provider"

  tags = local.tags
}

module "iam_github_oidc_provider_disabled" {
  source = "./modules/iam-github-oidc-provider"

  create = false
}

################################################################################
# GitHub OIDC Role
################################################################################

module "iam_github_oidc_role" {
  source   = "./modules/iam-github-oidc-role"
  subjects = var.subjects

  name = local.name

  # This should be updated to suit your organization, repository, references/branches, etc.
  # subjects = [
  #   # You can prepend with `repo:` but it is not required
  #   "repo:terraform-aws-modules/terraform-aws-iam:pull_request",
  #   "terraform-aws-modules/terraform-aws-iam:ref:refs/heads/master",
  # ]

  policies = {
    additional = aws_iam_policy.additional.arn,
    Admin      = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  tags = local.tags
}

module "iam_github_oidc_role_disabled" {
  source   = "./modules/iam-github-oidc-role"
  subjects = var.subjects

  create = false
}

################################################################################
# Supporting Resources
################################################################################

resource "aws_iam_policy" "additional" {
  name        = "${local.name}-additional"
  description = "Additional test policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}
