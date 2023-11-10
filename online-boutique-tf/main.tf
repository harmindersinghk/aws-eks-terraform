locals {
  name   = "eks-cluster"
  region = "eu-west-1"
}


resource "kubernetes_namespace" "online_boutique_ns" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "online_boutique" {
  name      = "onlineboutique"
  chart     = "${path.module}/helm"
  version   = "0.1.0"
  namespace = var.namespace
}
