variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "practice-dev"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Starts on 1.35 to practice upgrades (1.35 -> 1.36 -> 1.37, one minor at a time)."
  type        = string
  default     = "1.35"
}

variable "allowed_cidrs" {
  description = "Your public IP as /32. Find it with: curl -s https://checkip.amazonaws.com"
  type        = list(string)
}

variable "system_node_count" {
  description = "Number of on-demand system nodes (1 or 2)."
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "VPC CIDR block (/16)."
  type        = string
  default     = "10.0.0.0/16"
}
