output "alb_ingress_controller_role_arn" {
  description = "IAM role ARN for ALB Ingress Controller"
  value       = var.enable_alb_ingress ? aws_iam_role.alb_ingress_controller[0].arn : ""
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = aws_iam_role.external_dns.arn
}

output "fluentbit_role_arn" {
  description = "IAM role ARN for FluentBit"
  value       = var.enable_cloudwatch_logs ? aws_iam_role.fluentbit[0].arn : ""
}
