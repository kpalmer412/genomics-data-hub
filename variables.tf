variable "vpc_cidr" {
  type        = string
  description = "Primary CIDR block for the Genomics Hub VPC"
  default     = "10.100.0.0/16"
}

variable "environment" {
  type        = string
  description = "Deployment environment (Dev-Sandbox, Staging, Prod)"
  default     = "Dev-Sandbox"
}
variable "state_bucket_name" {
  description = "The name of the private S3 bucket holding remote state data"
  type        = string
}
