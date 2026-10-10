variable "name" {
  description = "Name prefix for VPC resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name. Used for Karpenter discovery tags."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block. Must be a /16."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = endswith(var.cidr, "/16")
    error_message = "The subnet layout assumes a /16 VPC CIDR."
  }
}

variable "azs" {
  description = "Exactly 3 availability zones."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 3
    error_message = "Provide exactly 3 availability zones."
  }
}

variable "tags" {
  description = "Extra tags for all VPC resources."
  type        = map(string)
  default     = {}
}
