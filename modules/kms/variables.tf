variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window in days"
  type        = number
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
