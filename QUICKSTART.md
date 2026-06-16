# Quick Start Guide

## Prerequisites

1. **Install Required Tools**:
   - [AWS CLI](https://aws.amazon.com/cli/)
   - [Terraform](https://www.terraform.io/downloads) >= 1.5.0
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)
   - [Helm](https://helm.sh/docs/intro/install/)

2. **Configure AWS Credentials**:
   ```bash
   aws configure
   ```

3. **Create SSH Key** (for bastion host):
   ```bash
   aws ec2 create-key-pair --key-name my-eks-key --query 'KeyMaterial' --output text > my-eks-key.pem
   chmod 400 my-eks-key.pem
   ```

## Step-by-Step Deployment

### Step 1: Configure Variables

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
notepad terraform.tfvars  # or use your favorite editor
```

**Minimum required changes in `terraform.tfvars`:**
```hcl
cluster_name          = "my-production-cluster"
owner                 = "Your Name"
bastion_allowed_cidrs = ["YOUR_IP/32"]  # Get your IP: curl ifconfig.me
bastion_key_name      = "my-eks-key"
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan -out=tfplan
```

Review the resources that will be created.

### Step 4: Deploy Infrastructure

```bash
terraform apply tfplan
```

⏱️ This takes **15-20 minutes**. Grab a coffee! ☕

### Step 5: Configure kubectl

```bash
# Get the command from Terraform output
aws eks update-kubeconfig --region us-east-1 --name my-production-cluster

# Verify
kubectl get nodes
kubectl get pods -A
```

## What Gets Created?

- ✅ VPC with 3 availability zones
- ✅ Public and private subnets
- ✅ NAT Gateways and Internet Gateway
- ✅ EKS Cluster with managed node groups
- ✅ Security groups
- ✅ ECR repositories (if specified)
- ✅ Bastion host
- ✅ ALB Ingress Controller
- ✅ CloudWatch monitoring
- ✅ KMS encryption keys
- ✅ IAM roles for service accounts

## Deploy a Test Application

```bash
# Deploy sample app
kubectl apply -f examples/kubernetes/sample-app.yaml

# Check status
kubectl get pods -n sample-app
kubectl get ingress -n sample-app
```

## View Outputs

```bash
# See all infrastructure details
terraform output

# Get specific values
terraform output cluster_endpoint
terraform output bastion_public_ip
terraform output ecr_repository_urls
```

## Cost Estimate

**Approximate monthly cost**: $400-800 USD

- EKS Control Plane: $73/month
- EC2 Nodes (3x t3.large): ~$230/month
- NAT Gateways (3): ~$100/month
- Load Balancer: ~$20/month
- Data Transfer: Variable

### Cost Optimization Tips:

1. **Use single NAT Gateway** (saves ~$66/month):
   ```hcl
   single_nat_gateway = true
   ```

2. **Use Spot instances** (saves 50-70%):
   ```hcl
   node_groups = {
     spot = {
       capacity_type = "SPOT"
       ...
     }
   }
   ```

3. **Scale down dev/test environments**:
   ```hcl
   node_groups = {
     general = {
       min_size = 1
       desired_size = 1
       ...
     }
   }
   ```

## Troubleshooting

### Issue: Cannot access cluster
```bash
# Verify cluster status
aws eks describe-cluster --name my-production-cluster --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig --name my-production-cluster --region us-east-1

# Check credentials
aws sts get-caller-identity
```

### Issue: Nodes not ready
```bash
# Check node status
kubectl get nodes -o wide

# View node group status
aws eks describe-nodegroup --cluster-name my-production-cluster --nodegroup-name general

# Check events
kubectl get events --all-namespaces
```

### Issue: Terraform errors
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Validate configuration
terraform validate

# Check formatting
terraform fmt -recursive
```

## Clean Up (Delete Everything)

**⚠️ WARNING: This deletes all resources and cannot be undone!**

```bash
# Delete all Kubernetes resources first
kubectl delete namespace sample-app

# Destroy infrastructure
terraform destroy
```

You'll be prompted to confirm by typing `yes`.

## Next Steps

1. **Set Up CI/CD Pipeline**
   - Configure GitHub Actions or Jenkins
   - Deploy applications automatically

2. **Install Additional Tools**
   ```bash
   # Metrics Server
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   
   # Kubernetes Dashboard (optional)
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
   ```

3. **Configure Monitoring**
   - Set up CloudWatch dashboards
   - Configure SNS alerts
   - Install Prometheus/Grafana (optional)

4. **Secure Your Cluster**
   - Enable Pod Security Standards
   - Configure Network Policies
   - Set up RBAC rules

## Useful Commands

```bash
# View all resources
kubectl get all -A

# Check cluster info
kubectl cluster-info

# View logs
kubectl logs -f <pod-name> -n <namespace>

# Execute commands in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port forward
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>

# Scale deployment
kubectl scale deployment <name> --replicas=5 -n <namespace>

# View Terraform state
terraform state list

# Import existing resource
terraform import <resource-type>.<name> <resource-id>
```

## Getting Help

- **Documentation**: See [README.md](README.md) for detailed information
- **Deployment Guide**: See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **AWS EKS Docs**: https://docs.aws.amazon.com/eks/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                  │   │
│  │                                                        │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │    AZ-1a    │  │    AZ-1b    │  │    AZ-1c    │  │   │
│  │  │             │  │             │  │             │  │   │
│  │  │  Public     │  │  Public     │  │  Public     │  │   │
│  │  │  Subnet     │  │  Subnet     │  │  Subnet     │  │   │
│  │  │  Bastion    │  │  NAT GW     │  │  NAT GW     │  │   │
│  │  │  NAT GW     │  │  ALB        │  │             │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │   │
│  │         │                │                │         │   │
│  │  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐  │   │
│  │  │  Private    │  │  Private    │  │  Private    │  │   │
│  │  │  Subnet     │  │  Subnet     │  │  Subnet     │  │   │
│  │  │  EKS Nodes  │  │  EKS Nodes  │  │  EKS Nodes  │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  │                                                        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ EKS Control  │  │ CloudWatch   │  │     ECR      │      │
│  │    Plane     │  │  Monitoring  │  │ Repositories │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

**Ready to deploy?** Start with Step 1! 🚀
