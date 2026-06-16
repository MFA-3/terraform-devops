locals {
  cluster_name = var.cluster_name
  common_tags = merge(
    var.additional_tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    }
  )
}

# KMS Key for Encryption
module "kms" {
  source = "./modules/kms"

  project_name                = var.project_name
  environment                 = var.environment
  kms_deletion_window_in_days = var.kms_deletion_window_in_days
  tags                        = local.common_tags
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  cluster_name         = local.cluster_name
  environment          = var.environment
  project_name         = var.project_name
  tags                 = local.common_tags
}

# Security Groups
module "security_groups" {
  source = "./modules/security-groups"

  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = var.vpc_cidr
  cluster_name         = local.cluster_name
  environment          = var.environment
  bastion_allowed_cidrs = var.bastion_allowed_cidrs
  tags                 = local.common_tags
}

# IAM Roles and Policies
module "iam" {
  source = "./modules/iam"

  cluster_name             = local.cluster_name
  environment              = var.environment
  oidc_provider_arn        = module.eks.oidc_provider_arn
  oidc_provider_url        = module.eks.oidc_provider_url
  enable_alb_ingress       = var.enable_alb_ingress_controller
  enable_cloudwatch_logs   = var.enable_cloudwatch_logs
  cloudwatch_log_group_arn = module.monitoring.cloudwatch_log_group_arn
  tags                     = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"

  cluster_name                         = local.cluster_name
  cluster_version                      = var.cluster_version
  vpc_id                               = module.vpc.vpc_id
  private_subnet_ids                   = module.vpc.private_subnet_ids
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  node_groups                          = var.node_groups
  node_security_group_id               = module.security_groups.node_security_group_id
  cluster_security_group_id            = module.security_groups.cluster_security_group_id
  kms_key_arn                          = module.kms.kms_key_arn
  enable_cloudwatch_logs               = var.enable_cloudwatch_logs
  cloudwatch_log_group_name            = module.monitoring.cloudwatch_log_group_name
  environment                          = var.environment
  tags                                 = local.common_tags

  depends_on = [module.vpc, module.security_groups]
}

# ECR Repositories
module "ecr" {
  source = "./modules/ecr"

  repositories         = var.ecr_repositories
  image_tag_mutability = var.ecr_image_tag_mutability
  scan_on_push         = var.ecr_scan_on_push
  lifecycle_policy     = var.ecr_lifecycle_policy
  kms_key_arn          = module.kms.kms_key_arn
  environment          = var.environment
  tags                 = local.common_tags
}

# Bastion Host
module "bastion" {
  source = "./modules/bastion"
  count  = var.enable_bastion ? 1 : 0

  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  bastion_instance_type = var.bastion_instance_type
  bastion_key_name      = var.bastion_key_name
  security_group_id     = module.security_groups.bastion_security_group_id
  environment           = var.environment
  project_name          = var.project_name
  tags                  = local.common_tags
}

# CloudWatch Monitoring and Logging
module "monitoring" {
  source = "./modules/monitoring"

  cluster_name                = local.cluster_name
  environment                 = var.environment
  enable_cloudwatch_logs      = var.enable_cloudwatch_logs
  log_retention_days          = var.cloudwatch_log_retention_days
  enable_container_insights   = var.enable_container_insights
  kms_key_arn                 = module.kms.kms_key_arn
  tags                        = local.common_tags
}

# Secrets Manager
module "secrets" {
  source = "./modules/secrets"

  secrets     = var.secrets
  kms_key_arn = module.kms.kms_key_arn
  environment = var.environment
  tags        = local.common_tags
}

# Route53 DNS
module "route53" {
  source = "./modules/route53"
  count  = var.create_route53_zone ? 1 : 0

  domain_name  = var.domain_name
  environment  = var.environment
  tags         = local.common_tags
}

# ACM Certificates
module "acm" {
  source = "./modules/acm"
  count  = var.create_route53_zone && var.domain_name != "" ? 1 : 0

  domain_name       = var.domain_name
  zone_id           = module.route53[0].zone_id
  environment       = var.environment
  tags              = local.common_tags

  depends_on = [module.route53]
}

# ALB Ingress Controller
module "alb_ingress_controller" {
  source = "./modules/alb-ingress-controller"
  count  = var.enable_alb_ingress_controller ? 1 : 0

  cluster_name                 = local.cluster_name
  cluster_endpoint             = module.eks.cluster_endpoint
  oidc_provider_arn            = module.eks.oidc_provider_arn
  alb_ingress_controller_role_arn = module.iam.alb_ingress_controller_role_arn
  vpc_id                       = module.vpc.vpc_id
  aws_region                   = var.aws_region
  tags                         = local.common_tags

  depends_on = [module.eks, module.iam]
}
