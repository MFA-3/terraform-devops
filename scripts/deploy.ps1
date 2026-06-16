# Deployment script for Windows PowerShell

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "plan",
    
    [Parameter(Mandatory=$false)]
    [string]$VarFile = "terraform.tfvars",
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "=========================================="
Write-ColorOutput Green "  AWS EKS Infrastructure Deployment"
Write-ColorOutput Green "=========================================="
Write-Host ""

# Check prerequisites
Write-ColorOutput Yellow "Checking prerequisites..."

# Check AWS CLI
try {
    $awsVersion = aws --version
    Write-ColorOutput Green "✓ AWS CLI found: $awsVersion"
} catch {
    Write-ColorOutput Red "✗ AWS CLI not found. Please install AWS CLI."
    exit 1
}

# Check Terraform
try {
    $tfVersion = terraform version -json | ConvertFrom-Json
    Write-ColorOutput Green "✓ Terraform found: $($tfVersion.terraform_version)"
} catch {
    Write-ColorOutput Red "✗ Terraform not found. Please install Terraform >= 1.5.0"
    exit 1
}

# Check kubectl
try {
    $kubectlVersion = kubectl version --client -o json | ConvertFrom-Json
    Write-ColorOutput Green "✓ kubectl found"
} catch {
    Write-ColorOutput Yellow "⚠ kubectl not found. Install it to manage the cluster."
}

# Check AWS credentials
Write-ColorOutput Yellow "Checking AWS credentials..."
try {
    $identity = aws sts get-caller-identity | ConvertFrom-Json
    Write-ColorOutput Green "✓ AWS credentials valid"
    Write-Host "  Account: $($identity.Account)"
    Write-Host "  User: $($identity.Arn)"
} catch {
    Write-ColorOutput Red "✗ AWS credentials not configured or invalid"
    exit 1
}

Write-Host ""

# Check if tfvars file exists
if (-not (Test-Path $VarFile)) {
    Write-ColorOutput Red "✗ Variable file '$VarFile' not found"
    Write-ColorOutput Yellow "  Copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
}

Write-ColorOutput Green "✓ Variable file found: $VarFile"
Write-Host ""

# Terraform operations
switch ($Action) {
    "init" {
        Write-ColorOutput Yellow "Initializing Terraform..."
        terraform init
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        terraform validate
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-ColorOutput Green "✓ Terraform initialized successfully"
    }
    
    "plan" {
        Write-ColorOutput Yellow "Creating Terraform plan..."
        terraform plan -var-file=$VarFile -out=tfplan
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-ColorOutput Green "✓ Plan created successfully"
        Write-ColorOutput Yellow "Review the plan above, then run: .\scripts\deploy.ps1 -Action apply"
    }
    
    "apply" {
        if (-not (Test-Path "tfplan")) {
            Write-ColorOutput Red "✗ No plan file found. Run 'plan' first."
            exit 1
        }
        
        if (-not $AutoApprove) {
            Write-ColorOutput Yellow "About to apply Terraform plan..."
            $confirmation = Read-Host "Type 'yes' to continue"
            if ($confirmation -ne "yes") {
                Write-ColorOutput Red "Deployment cancelled"
                exit 0
            }
        }
        
        Write-ColorOutput Yellow "Applying Terraform plan..."
        terraform apply tfplan
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        
        Write-Host ""
        Write-ColorOutput Green "=========================================="
        Write-ColorOutput Green "  Deployment completed successfully!"
        Write-ColorOutput Green "=========================================="
        Write-Host ""
        
        # Get cluster name from output
        $clusterName = terraform output -raw cluster_name
        $region = terraform output -raw aws_region
        
        Write-ColorOutput Yellow "Next steps:"
        Write-Host "1. Configure kubectl:"
        Write-ColorOutput Cyan "   aws eks update-kubeconfig --region $region --name $clusterName"
        Write-Host ""
        Write-Host "2. Verify cluster:"
        Write-ColorOutput Cyan "   kubectl get nodes"
        Write-Host ""
        Write-Host "3. Check system pods:"
        Write-ColorOutput Cyan "   kubectl get pods -A"
        Write-Host ""
        
        # Show outputs
        Write-ColorOutput Yellow "Important outputs:"
        terraform output
    }
    
    "destroy" {
        Write-ColorOutput Red "=========================================="
        Write-ColorOutput Red "  WARNING: DESTRUCTIVE OPERATION"
        Write-ColorOutput Red "=========================================="
        Write-Host ""
        Write-ColorOutput Yellow "This will destroy ALL resources created by Terraform."
        Write-ColorOutput Yellow "This action cannot be undone!"
        Write-Host ""
        
        $confirmation = Read-Host "Type 'destroy' to continue"
        if ($confirmation -ne "destroy") {
            Write-ColorOutput Green "Operation cancelled"
            exit 0
        }
        
        Write-ColorOutput Yellow "Destroying infrastructure..."
        terraform destroy -var-file=$VarFile
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        
        Write-ColorOutput Green "✓ Infrastructure destroyed"
    }
    
    "output" {
        Write-ColorOutput Yellow "Terraform outputs:"
        terraform output
    }
    
    default {
        Write-ColorOutput Red "Unknown action: $Action"
        Write-Host "Valid actions: init, plan, apply, destroy, output"
        exit 1
    }
}
