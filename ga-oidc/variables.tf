variable "subjects" {
  description = "List of GitHub OIDC subjects that are permitted by the trust policy. You do not need to prefix with `repo:` as this is provided. Example: `['my-org/my-repo:*', 'octo-org/octo-repo:ref:refs/heads/octo-branch']`"
  type        = list(string)
  default     = []
}