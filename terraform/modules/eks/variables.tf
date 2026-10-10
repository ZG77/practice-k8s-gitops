variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the control plane ENIs and the nodes."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (your IP as /32)."
  type        = list(string)

  validation {
    condition     = !contains(var.allowed_cidrs, "0.0.0.0/0")
    error_message = "Do not open the API endpoint to the whole internet."
  }
}

variable "enabled_log_types" {
  description = "Control plane log types. Options: api, audit, authenticator, controllerManager, scheduler."
  type        = list(string)
  default     = ["authenticator"]
}

variable "system_instance_type" {
  description = "Instance type for the system node group (arm64)."
  type        = string
  default     = "t4g.medium"
}

variable "system_node_count" {
  description = "Number of system nodes."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Extra tags for EKS resources."
  type        = map(string)
  default     = {}
}
