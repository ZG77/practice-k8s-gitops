# AWS side of Karpenter only. The Helm chart, EC2NodeClass and NodePool are in platform/karpenter (Argo CD).
#
# Fixed names (no random prefix), so the Git manifests can refer to them:
#   controller role: <cluster>-karpenter-controller
#   node role:       <cluster>-karpenter-node   -> EC2NodeClass spec.role
#   SQS queue:       <cluster>-karpenter        -> Helm settings.interruptionQueue
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.29"

  cluster_name = var.cluster_name

  # Controller: IAM role + EKS Pod Identity association.
  iam_role_name                   = "${var.cluster_name}-karpenter-controller"
  iam_role_use_name_prefix        = false
  create_pod_identity_association = true
  # The controller policy is larger than the managed policy limit (6,144 chars).
  # An inline role policy allows 10,240 chars.
  enable_inline_policy = true
  namespace            = var.namespace
  service_account      = var.service_account

  # Nodes: IAM role + EKS access entry, so new nodes can join the cluster.
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"
  node_iam_role_use_name_prefix = false
  node_iam_role_additional_policies = {
    # Shell access with SSM Session Manager. No SSH keys needed.
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Interruption handling: SQS queue + EventBridge rules
  # (Spot interruption, rebalance, instance state change, scheduled health events).
  enable_spot_termination = true
  queue_name              = "${var.cluster_name}-karpenter"

  tags = var.tags
}
