# Deployment Guide

This guide provides detailed step-by-step instructions for deploying the AWS EKS infrastructure.

## Pre-Deployment Checklist

- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.5.0 installed
- [ ] kubectl installed
- [ ] Helm 3.x installed
- [ ] AWS account with appropriate permissions
- [ ] SSH key pair created (for bastion host)
- [ ] Domain registered (if using Route53)

## Step 1: Prepare AWS Account

### Create IAM User/Role

Ensure your AWS credentials have the following permissions:
- EC2 (Full)
- EKS (Full)
- VPC (Full)
- IAM (Full)
- KMS (Full)
- CloudWatch (Full)
- S3 (Create/Write)
- DynamoDB (Create/Write)

### Set Up Backend Storage

```bash
# Set your bucket name
BUCKET_NAME="your-terraform-state-bucket"
REGION="us-east-1"

# Create S3 bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    BlockPublicAcls=true,\
    IgnorePublicAcls=true,\
    BlockPublicPolicy=true,\
    RestrictPublicBuckets=true

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION
```

## Step 2: Configure Terraform

### Clone/Download Repository

```bash
cd /path/to/your/workspace
```

### Configure Backend

Edit `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "eks-infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Configure Variables

Create `terraform.tfvars`:

```hcl
# General Configuration
aws_region   = "us-east-1"
environment  = "prod"
project_name = "my-eks-cluster"
owner        = "DevOps Team"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = false  # Set to true for cost savings

# EKS Configuration
cluster_name    = "my-production-cluster"
cluster_version = "1.28"

# Node Groups
node_groups = {
  general = {
    desired_size   = 3
    min_size       = 2
    max_size       = 5
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
    labels = {
      role = "general"
    }
    taints = []
  }
}

# ECR Repositories
ecr_repositories = [
  "my-app-frontend",
  "my-app-backend",
  "my-app-worker"
]

# Bastion Host
enable_bastion        = true
bastion_instance_type = "t3.micro"
bastion_allowed_cidrs = ["YOUR_IP/32"]  # Replace with your IP
bastion_key_name      = "my-ssh-key"    # Replace with your key name

# DNS (Optional)
domain_name         = "example.com"
create_route53_zone = true

# Monitoring
enable_cloudwatch_logs       = true
cloudwatch_log_retention_days = 30
enable_container_insights    = true
```

## Step 3: Initialize Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

## Step 4: Review Plan

```bash
# Create and review execution plan
terraform plan -out=tfplan

# Review the plan carefully:
# - Check resource counts
# - Verify configurations
# - Review estimated costs
```

## Step 5: Deploy Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# This will take approximately 15-20 minutes
# Monitor the progress and ensure no errors occur
```

## Step 6: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name my-production-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

## Step 7: Verify Deployments

### Check EKS Cluster

```bash
# Get cluster information
aws eks describe-cluster --name my-production-cluster --region us-east-1

# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system
```

### Check Add-ons

```bash
# Verify EKS add-ons
aws eks list-addons --cluster-name my-production-cluster --region us-east-1

# Check ALB controller
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Check Security

```bash
# Verify security groups
aws ec2 describe-security-groups --region us-east-1 | grep my-production-cluster

# Check IAM OIDC provider
aws iam list-open-id-connect-providers
```

## Step 8: Deploy Cluster Autoscaler

Create `cluster-autoscaler.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: <CLUSTER_AUTOSCALER_ROLE_ARN>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-production-cluster
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
```

Apply:

```bash
# Get the role ARN from Terraform output
ROLE_ARN=$(terraform output -raw cluster_autoscaler_role_arn)

# Update the YAML with the role ARN
sed -i "s|<CLUSTER_AUTOSCALER_ROLE_ARN>|$ROLE_ARN|g" cluster-autoscaler.yaml

# Deploy
kubectl apply -f cluster-autoscaler.yaml

# Verify
kubectl get pods -n kube-system | grep cluster-autoscaler
```

## Step 9: Configure Monitoring

### Subscribe to SNS Alerts

```bash
# Get SNS topic ARN
SNS_TOPIC=$(terraform output -raw monitoring_sns_topic_arn)

# Subscribe with email
aws sns subscribe \
  --topic-arn $SNS_TOPIC \
  --protocol email \
  --notification-endpoint your-email@example.com

# Confirm subscription from email
```

### Access CloudWatch Dashboard

```bash
# Get dashboard name
DASHBOARD=$(terraform output -raw cloudwatch_dashboard_name)

# Open in browser
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=$DASHBOARD"
```

## Step 10: Test Deployment

### Deploy Sample Application

```bash
# Create test namespace
kubectl create namespace test-app

# Deploy nginx
kubectl create deployment nginx --image=nginx -n test-app
kubectl expose deployment nginx --port=80 --type=LoadBalancer -n test-app

# Wait for LoadBalancer
kubectl get svc -n test-app -w

# Test
curl http://<LOAD_BALANCER_DNS>

# Cleanup
kubectl delete namespace test-app
```

## Post-Deployment Tasks

### 1. Document Outputs

```bash
# Save all outputs
terraform output > infrastructure-outputs.txt

# Save kubeconfig
kubectl config view > kubeconfig-backup.yaml
```

### 2. Set Up Backup

```bash
# Install Velero for cluster backup
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.backupStorageLocation[0].bucket=my-backup-bucket \
  --set configuration.backupStorageLocation[0].provider=aws
```

### 3. Configure Access Control

```bash
# Create RBAC roles for your team
kubectl apply -f rbac-config.yaml

# Map IAM users to Kubernetes RBAC
kubectl edit configmap aws-auth -n kube-system
```

### 4. Enable Audit Logging

Audit logs are automatically enabled and sent to CloudWatch. Review:

```bash
# View audit logs
aws logs tail /aws/eks/my-production-cluster/cluster --follow
```

## Troubleshooting Deployment

### Issue: Terraform Apply Fails

```bash
# Check credentials
aws sts get-caller-identity

# Check resource limits
aws service-quotas list-service-quotas --service-code eks

# Enable detailed logging
export TF_LOG=DEBUG
terraform apply
```

### Issue: Cannot Access Cluster

```bash
# Verify cluster status
aws eks describe-cluster --name my-production-cluster

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*my-production-cluster*"

# Update kubeconfig
aws eks update-kubeconfig --name my-production-cluster --region us-east-1
```

### Issue: Nodes Not Joining

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name my-production-cluster \
  --nodegroup-name general

# Check IAM role
aws iam get-role --role-name my-production-cluster-node-group-role

# View node logs via Systems Manager
aws ssm start-session --target <INSTANCE_ID>
```

## Rollback Procedure

If deployment fails:

```bash
# Destroy specific resources
terraform destroy -target=module.eks

# Or destroy everything
terraform destroy

# Restore from state backup
terraform state pull > backup.tfstate
```

## Next Steps

1. Review [OPERATIONS.md](OPERATIONS.md) for day-to-day operations
2. Set up CI/CD pipelines
3. Configure application deployments
4. Set up monitoring alerts
5. Document runbooks

## Support

For deployment issues:
1. Check Terraform logs
2. Review CloudWatch logs
3. Check AWS service health dashboard
4. Open an issue in the repository
