output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "azs" {
  value = module.vpc.azs
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "karpenter_queue_name" {
  value = module.karpenter_aws.queue_name
}

output "karpenter_node_role_name" {
  value = module.karpenter_aws.node_iam_role_name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
