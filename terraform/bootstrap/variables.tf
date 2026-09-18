variable "project_name" {
  type        = string
  description = "Project Name"

  default = "ai-platform-infra"
}

variable "environment" {
  type        = string
  description = "Deployment Environment"

  default = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"

  default = "ap-south-1"
}

variable "terraform_state_bucket" {
  type = string
}

variable "terraform_lock_table" {
  type = string
}
