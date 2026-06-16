# Backend configuration script
# Run this before terraform init

$BUCKET_NAME = "your-terraform-state-bucket"
$REGION = "us-east-1"
$TABLE_NAME = "terraform-state-lock"

Write-Host "Creating S3 bucket for Terraform state..." -ForegroundColor Green

# Create S3 bucket
aws s3api create-bucket `
  --bucket $BUCKET_NAME `
  --region $REGION

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket $BUCKET_NAME `
  --versioning-configuration Status=Enabled

# Enable encryption
$encryptionConfig = @"
{
  "Rules": [{
    "ApplyServerSideEncryptionByDefault": {
      "SSEAlgorithm": "AES256"
    },
    "BucketKeyEnabled": true
  }]
}
"@

aws s3api put-bucket-encryption `
  --bucket $BUCKET_NAME `
  --server-side-encryption-configuration $encryptionConfig

# Block public access
aws s3api put-public-access-block `
  --bucket $BUCKET_NAME `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

Write-Host "Creating DynamoDB table for state locking..." -ForegroundColor Green

# Create DynamoDB table
aws dynamodb create-table `
  --table-name $TABLE_NAME `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region $REGION

Write-Host "Backend resources created successfully!" -ForegroundColor Green
Write-Host "Update backend.tf with these values:" -ForegroundColor Yellow
Write-Host "  bucket = `"$BUCKET_NAME`"" -ForegroundColor Cyan
Write-Host "  dynamodb_table = `"$TABLE_NAME`"" -ForegroundColor Cyan
Write-Host "  region = `"$REGION`"" -ForegroundColor Cyan
