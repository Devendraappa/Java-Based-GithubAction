terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = terraform.workspace
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  env          = terraform.workspace
  cluster_name = "${var.project_name}-${local.env}-cluster"
}

# =========================================
# VPC MODULE
# =========================================
module "vpc" {
  source             = "./modules/vpc"
  project_name       = var.project_name
  env                = local.env
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  cluster_name       = local.cluster_name
}

# =========================================
# IAM MODULE
# =========================================
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  env          = local.env
}

# =========================================
# EKS MODULE
# =========================================
module "eks" {
  source              = "./modules/eks"
  project_name        = var.project_name
  env                 = local.env
  cluster_name        = local.cluster_name
  region              = var.region
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size
  cluster_role_arn    = module.iam.cluster_role_arn
  node_role_arn       = module.iam.node_role_arn
  node_role_name      = module.iam.node_role_name

  depends_on = [module.vpc, module.iam]
}

# =========================================
# ECR MODULE
# Only created in prod workspace
# Dev uses same prod ECR repo
# =========================================
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  region       = var.region
  env          = local.env 
  count        = terraform.workspace == "prod" ? 1 : 0
}