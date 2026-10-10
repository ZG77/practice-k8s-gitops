# Long-lived resources. Do NOT destroy this stack after each session.
# The images in ECR must survive the cluster (terraform/envs/dev) being destroyed.
#
# Contents:
#   - ECR repositories: practice-k8s/<service>
#   - GitHub OIDC provider + IAM role: CI pushes images with no stored AWS keys

# --- ECR ---------------------------------------------------------------------

resource "aws_ecr_repository" "service" {
  for_each = var.services

  name = "practice-k8s/${each.key}"

  # A tag always points to the same image. CI tags with the git SHA.
  image_tag_mutability = "IMMUTABLE"
  # Allow terraform destroy even if images exist.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true # basic scanning, free
  }
}

# Keep the last 20 tagged images per repo (cost).
# No rule for untagged images: the per-arch images of a multi-arch index are untagged.
resource "aws_ecr_lifecycle_policy" "service" {
  for_each = aws_ecr_repository.service

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 tagged images"
      selection = {
        tagStatus      = "tagged"
        tagPatternList = ["*"]
        countType      = "imageCountMoreThan"
        countNumber    = 20
      }
      action = { type = "expire" }
    }]
  })
}

# --- GitHub Actions OIDC -----------------------------------------------------

# One provider per account. GitHub signs a short-lived token for each workflow run.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only the main branch of the apps repo. Pull requests and forks cannot push images.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_apps_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name                 = "practice-k8s-github-ci"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ecr_push" {
  # Login token. This action does not support resource-level permissions.
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push and pull, only on our repositories.
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [for r in aws_ecr_repository.service : r.arn]
  }
}

resource "aws_iam_role_policy" "github_ci_ecr" {
  name   = "ecr-push"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
