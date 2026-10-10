output "queue_name" {
  description = "SQS interruption queue name (Helm settings.interruptionQueue)."
  value       = module.karpenter.queue_name
}

output "node_iam_role_name" {
  description = "Node IAM role name (EC2NodeClass spec.role)."
  value       = module.karpenter.node_iam_role_name
}

output "controller_iam_role_arn" {
  description = "Controller IAM role ARN."
  value       = module.karpenter.iam_role_arn
}
