# Terraform Backend Configuration
# Uncomment and configure after creating S3 bucket and DynamoDB table
# Run: .\scripts\setup-backend.ps1 first

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "eks-infrastructure/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     kms_key_id     = "arn:aws:kms:region:account:key/key-id"
#     dynamodb_table = "terraform-state-lock"
#   }
# }
