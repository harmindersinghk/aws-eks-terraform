variable "cluster_name" {
  description = "AWS EKS Cluster Name"
  type        = string
  default     = "eks-cluster"
}

variable "enable_argocd" {
  description = "Enable Argo CD Kubernetes add-on"
  type        = bool
  default     = false
}

variable "argocd_manage_add_ons" {
  description = "Enable managing add-on configuration via ArgoCD App of Apps"
  type        = bool
  default     = false
}

variable "enable_calico" {
  description = "Enable Calico add-on"
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Enable Cert Manager add-on"
  type        = bool
  default     = false
}

variable "enable_metrics_server" {
  description = "Enable metrics server add-on"
  type        = bool
  default     = false
}