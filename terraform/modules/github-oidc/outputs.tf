output "github_actions_role_arn" {
  description = "Put this in the GitHub secret AWS_DEPLOY_ROLE_ARN"
  value       = aws_iam_role.github_actions_deploy.arn
}
