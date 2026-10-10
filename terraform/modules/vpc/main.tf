# Subnet layout for a /16 VPC:
#   private: 3 x /19 (8190 IPs each). VPC CNI gives every pod a VPC IP, so private subnets are large.
#   public:  3 x /24 (254 IPs each). Only the ALB and the NAT gateway use them.
locals {
  private_subnets = [for i in range(3) : cidrsubnet(var.cidr, 3, i)]      # 10.0.0.0/19, 10.0.32.0/19, 10.0.64.0/19
  public_subnets  = [for i in range(3) : cidrsubnet(var.cidr, 8, 96 + i)] # 10.0.96.0/24, 10.0.97.0/24, 10.0.98.0/24
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = var.name
  cidr = var.cidr
  azs  = var.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # One NAT gateway for the whole VPC (cost).
  # Trade-off: if its AZ fails, private subnets in all AZs lose internet access.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Public subnets: internet-facing ALB.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  # Private subnets: internal ALB, and Karpenter node discovery.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
  }

  tags = var.tags
}

# S3 gateway endpoint is free. ECR stores image layers in S3,
# so image pulls skip the NAT gateway and its data charge.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}

data "aws_region" "current" {}
