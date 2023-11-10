variable "namespace" {
  type        = string
  description = "sample app"
  default     = "app1"
}

variable "cluster_name" {
  description = "AWS EKS Cluster Name"
  type        = string
  default     = "eks-cluster"
}