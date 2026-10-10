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

variable "github_apps_repo" {
  description = "GitHub repo (owner/name) whose CI may push images."
  type        = string
  default     = "ZG77/practice-k8s-apps"
}
