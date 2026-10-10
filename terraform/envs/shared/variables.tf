variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "services" {
  description = "One ECR repository per service."
  type        = set(string)
  default     = ["web", "api", "worker"]
}

variable "github_apps_sub_prefix" {
  description = <<-EOT
    OIDC "sub" prefix of the repo whose CI may push images.
    GitHub uses immutable subjects (owner and repo IDs), so a deleted and re-created repo with the same name does not match.
    Find it with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
  EOT
  type        = string
  default     = "repo:ZG77@6376427/practice-k8s-apps@1413078599"
}
