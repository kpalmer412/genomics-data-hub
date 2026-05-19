# =============================================================================
# Root Outputs — Genomics Data Hub
# =============================================================================
# PURPOSE: Expose networking layer values for consumption by future modules.
# Compute module will need subnet IDs for AWS Batch placement.
# Storage module will need VPC ID for S3 VPC Endpoint attachment.
# =============================================================================

output "vpc_id" {
  description = "Genomics Hub VPC ID — used by compute and storage modules"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — genomic compute and database placement"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs — load balancers and NAT Gateway placement"
  value       = module.networking.public_subnet_ids
}
