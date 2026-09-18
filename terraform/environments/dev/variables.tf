variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "github_repo" {
  description = "GitHub repo allowed to deploy via CI/CD, as \"org-or-user/repo-name\""
  type        = string
}

variable "create_oidc_provider" {
  description = "Set to false if a GitHub OIDC provider already exists in this AWS account"
  type        = bool
  default     = true
}
