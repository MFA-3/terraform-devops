resource "aws_secretsmanager_secret" "main" {
  for_each = var.secrets

  name        = "${var.environment}-${each.key}"
  description = each.value.description
  kms_key_id  = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${each.key}"
    }
  )
}

resource "aws_secretsmanager_secret_version" "main" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.main[each.key].id
  secret_string = jsonencode(each.value.secret_data)
}
