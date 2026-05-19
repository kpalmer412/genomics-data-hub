variable "vpc_cidr" {
  type        = string
  description = "The CIDR block passed from the root configuration"
}



variable "environment" {
  type        = string
  description = "Deployment environment tag (Dev-Sandbox, Staging, Prod)"
  default     = "Dev-Sandbox"
}
