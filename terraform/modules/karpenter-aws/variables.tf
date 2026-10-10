variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "namespace" {
  description = "Namespace of the Karpenter controller. Must match the Helm release namespace."
  type        = string
  default     = "karpenter"
}

variable "service_account" {
  description = "Service account of the Karpenter controller. Must match the Helm values."
  type        = string
  default     = "karpenter"
}

variable "tags" {
  description = "Extra tags for Karpenter AWS resources."
  type        = map(string)
  default     = {}
}
