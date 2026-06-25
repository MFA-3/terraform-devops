# Production-Grade AWS EKS Infrastructure

This repository contains Terraform code to provision a production-ready AWS EKS (Elastic Kubernetes Service) infrastructure with comprehensive security, networking, monitoring, and operational capabilities.

## 🏗️ Architecture Overview

This infrastructure includes:

- **VPC & Networking**: 3-AZ VPC with public/private subnets, NAT Gateways, Internet Gateway
- **EKS Cluster**: Fully managed Kubernetes cluster with managed node groups
- **Security**: Security groups, KMS encryption, IAM roles for service accounts (IRSA)
- **Container Registry**: ECR repositories with image scanning and lifecycle policies
- **Load Balancing**: AWS ALB Ingress Controller for application load balancing
- **DNS & SSL/TLS**: Route53 hosted zone and ACM certificates
- **Monitoring**: CloudWatch logs, Container Insights, custom dashboards and alarms
- **Access Management**: Bastion host for secure SSH access
- **Secrets Management**: AWS Secrets Manager with KMS encryption
- **Auto Scaling**: Cluster autoscaler for dynamic node scaling
- **State Management**: S3 backend with DynamoDB locking

## 📋 Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- kubectl
- Helm 3.x
- An existing AWS account with appropriate permissions
- SSH key pair for bastion host (optional)

## 🚀 Quick Start

### 1. Configure Backend

First, create an S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

Update `backend.tf` with your bucket details:

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

### 2. Configure Variables

Copy the example tfvars file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific configuration:

```hcl
# Required changes:
cluster_name          = "my-prod-cluster"
owner                 = "Your Team Name"
domain_name           = "yourdomain.com"
bastion_allowed_cidrs = ["YOUR_IP/32"]
bastion_key_name      = "your-ssh-key-name"
```

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

The deployment takes approximately 15-20 minutes.

### 4. Configure kubectl

After successful deployment, configure kubectl to access your cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name my-prod-cluster
```

Verify cluster access:

```bash
kubectl get nodes
kubectl get pods -A
```

## 📁 Project Structure

```
.
├── main.tf                     # Root module configuration
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
├── provider.tf                 # Provider configurations
├── backend.tf                  # Backend configuration
├── versions.tf                 # Version constraints
├── terraform.tfvars.example    # Example variable values
├── modules/
│   ├── vpc/                   # VPC and networking
│   ├── eks/                   # EKS cluster and node groups
│   ├── security-groups/       # Security group configurations
│   ├── iam/                   # IAM roles for service accounts
│   ├── kms/                   # KMS encryption keys
│   ├── ecr/                   # Container registries
│   ├── bastion/               # Bastion host
│   ├── monitoring/            # CloudWatch monitoring
│   ├── secrets/               # Secrets Manager
│   ├── route53/               # DNS management
│   ├── acm/                   # SSL/TLS certificates
│   └── alb-ingress-controller/ # ALB Ingress Controller
├── docs/
│   ├── DEPLOYMENT.md          # Detailed deployment guide
│   ├── OPERATIONS.md          # Operations and maintenance
│   └── TROUBLESHOOTING.md     # Troubleshooting guide
└── examples/
    └── kubernetes/            # Example K8s manifests
```

## 🔧 Configuration Details

### VPC Configuration

- **CIDR Block**: 10.0.0.0/16 (configurable)
- **Availability Zones**: 3 AZs for high availability
- **Public Subnets**: For ALB and NAT Gateways
- **Private Subnets**: For EKS nodes and pods
- **NAT Gateways**: One per AZ (or single for cost optimization)

### EKS Configuration

- **Kubernetes Version**: 1.28 (configurable)
- **Node Groups**: Supports multiple node groups with different configurations
- **Add-ons**: VPC-CNI, CoreDNS, kube-proxy, EBS CSI driver
- **Encryption**: Secrets encrypted with KMS
- **Logging**: All control plane logs sent to CloudWatch

### Security Features

- **Network Isolation**: Private subnets for nodes
- **Encryption at Rest**: KMS encryption for EKS secrets, ECR, CloudWatch logs
- **Encryption in Transit**: TLS for all communications
- **IAM Roles for Service Accounts (IRSA)**: Fine-grained pod permissions
- **Security Groups**: Least-privilege network access
- **VPC Flow Logs**: Network traffic logging

### Monitoring & Logging

- **CloudWatch Logs**: Control plane and application logs
- **Container Insights**: Pod and node metrics
- **Custom Dashboards**: Pre-configured monitoring dashboards
- **Alarms**: CPU and memory utilization alerts
- **SNS Topics**: Alert notifications

## 📊 Outputs

After deployment, Terraform provides important outputs:

```bash
terraform output
```

Key outputs include:
- VPC and subnet IDs
- EKS cluster endpoint and name
- ECR repository URLs
- Bastion host IP
- CloudWatch log groups
- kubectl configuration command

## 🔐 IAM Roles for Service Accounts

The following service accounts are pre-configured:

1. **AWS Load Balancer Controller**: Manages ALBs for Ingress resources
2. **Cluster Autoscaler**: Auto-scales node groups based on demand
3. **External DNS**: Manages Route53 records for services
4. **FluentBit**: Ships logs to CloudWatch

## 🎯 Post-Deployment Steps

### 1. Install Cluster Autoscaler

```bash
kubectl apply -f examples/kubernetes/cluster-autoscaler.yaml
```

### 2. Deploy Sample Application

```bash
kubectl apply -f examples/kubernetes/sample-app.yaml
```

### 3. Configure Monitoring Alerts

Update the SNS topic subscription in the AWS Console to receive alerts via email or other channels.

### 4. Set Up Backup Strategy

Configure automated EBS snapshots for persistent volumes:

```bash
kubectl apply -f examples/kubernetes/backup-cronjob.yaml
```

## 💰 Cost Optimization

### Production Environment
Estimated monthly cost: $400-800 USD
- EKS Control Plane: $73
- EC2 Nodes (3x t3.large): ~$230
- NAT Gateways (3): ~$100
- ALB: ~$20
- Data Transfer: Variable

### Cost Saving Tips

1. **Use Single NAT Gateway**: Set `single_nat_gateway = true` (saves ~$66/month)
2. **Use Spot Instances**: Configure spot node groups (saves 50-70%)
3. **Right-size Instances**: Monitor and adjust instance types
4. **Use S3 Gateway Endpoint**: Free data transfer to S3
5. **Enable VPC Endpoints**: Reduce NAT Gateway usage

## 🔄 Scaling

### Horizontal Node Scaling

The Cluster Autoscaler automatically scales nodes based on pod demands:

```yaml
# Configure in node groups
min_size     = 2
max_size     = 10
desired_size = 3
```

### Vertical Node Scaling

Modify instance types in `terraform.tfvars`:

```hcl
node_groups = {
  general = {
    instance_types = ["t3.xlarge"]  # Upgrade from t3.large
    ...
  }
}
```

## 🛡️ Security Best Practices

1. **Rotate Credentials**: Regularly rotate IAM credentials and SSH keys
2. **Update Security Groups**: Restrict bastion SSH access to specific IPs
3. **Enable GuardDuty**: AWS threat detection service
4. **Scan Container Images**: ECR image scanning is enabled by default
5. **Use Secrets Manager**: Never hardcode secrets in manifests
6. **Audit Logs**: Review CloudWatch logs regularly
7. **Update Kubernetes**: Keep cluster version up to date

## 🔄 Backup and Disaster Recovery

### State Backup
Terraform state is stored in S3 with versioning enabled. To restore:

```bash
aws s3api list-object-versions --bucket your-terraform-state-bucket
```

### EKS Backup
Use Velero for cluster backup:

```bash
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.backupStorageLocation[0].bucket=your-backup-bucket
```

## 🗑️ Cleanup

To destroy all resources:

```bash
# WARNING: This will delete everything
terraform destroy
```

To preserve data:
1. Create snapshots of EBS volumes
2. Export ECR images
3. Backup Secrets Manager secrets

## 📚 Additional Resources

- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly in a non-production environment
4. Submit a pull request

## 📝 License

This project is licensed under the MIT License.

## ⚠️ Important Notes

- **Production Use**: Review and adjust all configurations for your specific requirements
- **Security**: Replace all placeholder values (IPs, domains, etc.)
- **Costs**: Monitor AWS billing to avoid unexpected charges
- **Compliance**: Ensure configurations meet your compliance requirements

## 🆘 Support

For issues and questions:
1. Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Review Terraform and AWS CloudWatch logs
3. Open an issue in this repository

---

**Maintained by**: DevOps Teams
**Last Updated**: 2026-06-16  
**Version**: 1.0.0
