variable "jit_image" {
  type        = string
  description = "Path to JIT docker image"
}

variable "project_id" {
  type        = string
  description = "Project ID where JIT should get deployed"
}

variable "support_email" {
  type        = string
  description = "Support e-mail for IAP brand"
}

variable "application_title" {
  type        = string
  description = "IAP Application title"
}

variable "target_project_id" {
  type        = string
  description = "Target project ID"
}

variable "dns_name" {
  type        = string
  description = "Full DNS name for the domain to be connected to the LB"
}

variable "region" {
  type        = string
  description = "Deployment region"
}

variable "access_group" {
  type        = string
  description = "Google Group with Resource Accessor role for the IAP"
}

variable "roles" {
  type        = list(any)
  description = "List of roles that should be requestable via JIT solution"
}
