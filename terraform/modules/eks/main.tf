module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Public endpoint, open only to your IP.
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.allowed_cidrs

  # Access entries only (no aws-auth ConfigMap). The caller of `terraform apply` becomes cluster admin.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  # No customer KMS key. EKS already encrypts secrets with an AWS-owned key.
  # A customer key costs money and stays "pending deletion" for 7+ days after each destroy.
  create_kms_key    = false
  encryption_config = null

  # Control plane logs cost money. Enable more types only when you debug.
  enabled_log_types                      = var.enabled_log_types
  cloudwatch_log_group_retention_in_days = 1

  addons = {
    # Must exist before nodes join, or nodes stay NotReady.
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    # Tolerates the CriticalAddonsOnly taint by default, so it runs on system nodes.
    coredns = {}
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = [var.system_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = var.system_node_count
      desired_size = var.system_node_count

      labels = {
        "node-role" = "system"
      }

      # Only pods that tolerate this taint run here (Karpenter, CoreDNS, LB controller, Argo CD).
      taints = {
        critical = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  # Karpenter finds the node security group by this tag.
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}

# EBS CSI driver: IAM role for EKS Pod Identity.
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

# AWS managed policy. Specific EC2 actions only, no "*" actions.
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
