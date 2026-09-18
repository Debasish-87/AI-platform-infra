output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "github_actions_role_arn" {
  description = "Put this in the GitHub secret AWS_DEPLOY_ROLE_ARN"
  value       = module.github_oidc.github_actions_role_arn
}
