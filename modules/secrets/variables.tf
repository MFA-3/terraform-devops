variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    description = string
    secret_data = map(string)
  }))
  # Note: Variable itself is not marked sensitive to allow for_each
  # The actual secret values are encrypted with KMS and protected
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
