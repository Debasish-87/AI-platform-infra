variable "github_repo" {
  description = "GitHub repo allowed to assume this role, as \"org-or-user/repo-name\""
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name to grant kubectl access to"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the deploy role may push to"
  type        = string
}

variable "role_name" {
  description = "Name for the IAM role GitHub Actions assumes"
  type        = string
  default     = "ai-platform-infra-github-actions-deploy"
}

variable "create_oidc_provider" {
  description = "Set to false if a GitHub OIDC provider already exists in this AWS account (only one is allowed per account)"
  type        = bool
  default     = true
}
