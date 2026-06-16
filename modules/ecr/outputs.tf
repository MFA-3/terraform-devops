output "repository_urls" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.main : k => v.repository_url }
}

output "repository_arns" {
  description = "ECR repository ARNs"
  value       = { for k, v in aws_ecr_repository.main : k => v.arn }
}

output "repository_registry_ids" {
  description = "ECR repository registry IDs"
  value       = { for k, v in aws_ecr_repository.main : k => v.registry_id }
}
