output "secret_arns" {
  description = "ARNs of created secrets"
  value       = { for k, v in aws_secretsmanager_secret.main : k => v.arn }
}

output "secret_ids" {
  description = "IDs of created secrets"
  value       = { for k, v in aws_secretsmanager_secret.main : k => v.id }
}
