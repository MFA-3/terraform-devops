output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for EKS"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.eks[0].name : ""
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN for EKS"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.eks[0].arn : ""
}

output "application_log_group_name" {
  description = "CloudWatch log group name for applications"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.application[0].name : ""
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
