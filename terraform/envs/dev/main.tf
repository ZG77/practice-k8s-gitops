locals {
  tags = {
    Project     = "practice-k8s"
    Environment = "dev"
    ManagedBy   = "terraform"
    Cluster     = var.cluster_name
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name         = var.cluster_name
  cluster_name = var.cluster_name
  cidr         = var.vpc_cidr
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_cidrs      = var.allowed_cidrs
  system_node_count  = var.system_node_count
}

module "karpenter_aws" {
  source = "../../modules/karpenter-aws"

  # Depends on the cluster: access entry and Pod Identity association need it.
  cluster_name = module.eks.cluster_name
}
