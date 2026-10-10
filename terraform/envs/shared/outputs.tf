output "github_ci_role_arn" {
  description = "Set as GitHub variable AWS_ROLE_ARN in the apps repo."
  value       = aws_iam_role.github_ci.arn
}

output "ecr_repository_urls" {
  description = "Image repositories, by service."
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}
