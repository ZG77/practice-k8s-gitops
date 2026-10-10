output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs (nodes and pods)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB)."
  value       = module.vpc.public_subnets
}

output "azs" {
  description = "Availability zones in use."
  value       = module.vpc.azs
}

output "nat_public_ips" {
  description = "Public IP of the NAT gateway."
  value       = module.vpc.nat_public_ips
}
