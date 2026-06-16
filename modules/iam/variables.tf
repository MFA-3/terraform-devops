variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC Provider for EKS"
  type        = string
}

variable "enable_alb_ingress" {
  description = "Enable ALB Ingress Controller"
  type        = bool
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
}

variable "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
