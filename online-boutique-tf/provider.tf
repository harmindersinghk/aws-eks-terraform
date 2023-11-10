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

terraform {
  required_version = ">= 1.0"

    backend "s3" {
    bucket = "tf-state-eks-2023"
    key    = "sampleapp"
    region = "eu-west-2"
  }
}