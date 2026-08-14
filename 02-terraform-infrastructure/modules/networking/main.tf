# 1. Fetch available AZs dynamically for us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# 2. Dedicated Clinical Genomics VPC
resource "aws_vpc" "genomics" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "Genomics-Hub-VPC"
    Environment = "Dev-Sandbox"
    Compliance  = "HIPAA-Ready"
  }
}

# 3. Internet Gateway for Public Tier Route
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.genomics.id
  tags   = { Name = "Genomics-IGW" }
}

# 4. Public Subnets (For Load Balancers and NATs)
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.genomics.id
  cidr_block        = "10.100.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0] # us-east-1a
  tags              = { Name = "Genomics-Pub-1A" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.genomics.id
  cidr_block        = "10.100.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1] # us-east-1b
  tags              = { Name = "Genomics-Pub-1B" }
}

# 5. Private Subnets (For Isolated Compute & Genome Databases)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.genomics.id
  cidr_block        = "10.100.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0] # us-east-1a
  tags              = { Name = "Genomics-Priv-1A" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.genomics.id
  cidr_block        = "10.100.20.0/24"
  availability_zone = data.aws_availability_zones.available.names[1] # us-east-1b
  tags              = { Name = "Genomics-Priv-1B" }
}

# =============================================================================
# 6. Elastic IP for NAT Gateway
# =============================================================================
# PURPOSE: NAT Gateway requires a static public IP (EIP) to provide consistent
# outbound identity for private subnet traffic. This EIP persists even if the
# NAT Gateway is replaced, preventing downstream firewall rule updates.
#
# HIPAA RELEVANCE: Private subnet resources (genomic compute, databases) need
# outbound internet for software updates and external API calls WITHOUT being
# directly reachable from the internet. NAT Gateway satisfies this requirement.
#
# SANDBOX NOTE: This resource is written but NOT deployed (count = 0).
# Reason: NAT Gateway costs $0.045/hour + $0.045/GB data transfer.
# 24-hour cost estimate: ~$1.08 base + data transfer charges.
# To deploy for testing: change count = 0 to count = 1, run terraform apply,
# validate, then terraform destroy immediately after.
# Production deployment: managed via Terraform workspace (staging/prod).
# =============================================================================

resource "aws_eip" "nat" {
  count  = 0  # Set to 1 to deploy — see SANDBOX NOTE above
  domain = "vpc"

  tags = {
    Name        = "Genomics-NAT-EIP"
    Environment = var.environment
    Compliance  = "HIPAA-Ready"
    CostCenter  = "GenomicsInfra"
  }
}

# =============================================================================
# 7. NAT Gateway (Public Subnet A — Primary AZ)
# =============================================================================
# PURPOSE: Provides outbound-only internet access for private subnet resources.
# Deployed in public_a (not private) because NAT Gateway needs IGW reachability
# to forward traffic. Private subnets route 0.0.0.0/0 to this NAT Gateway.
#
# ARCHITECTURE DECISION — Why NAT Gateway over alternatives:
#
#   NAT Instance (EC2 t3.nano ~$0.12/24hrs):
#     REJECTED for production — no built-in HA, manual failover required,
#     OS patching burden, incompatible with HIPAA automated patch compliance.
#     Acceptable ONLY in non-regulated sandbox environments.
#
#   VPC Endpoints (Interface/Gateway):
#     NOT a NAT replacement — handles AWS service traffic only (S3, DynamoDB).
#     Used ALONGSIDE NAT Gateway in this architecture. See Section 8.
#
#   Internet Gateway on private subnet:
#     REJECTED — makes subnet public by definition. HIPAA violation.
#
#   Transit Gateway:
#     REJECTED for this use case — routes between VPCs/on-premises,
#     not an internet egress solution. Relevant for multi-VPC genomics
#     hub expansion in future architecture iterations.
#
# COST: $0.045/hour ($32.40/month) + $0.045/GB data processed
# 24-HOUR ESTIMATE: $1.08 base (sandbox with minimal data transfer)
# HA NOTE: Production architecture deploys NAT Gateway per AZ (nat_a + nat_b)
# to eliminate cross-AZ data transfer charges and single-AZ failure risk.
# =============================================================================

resource "aws_nat_gateway" "primary" {
  count         = 0  # Set to 1 to deploy — see SANDBOX NOTE above
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name        = "Genomics-NAT-Primary"
    Environment = var.environment
    Compliance  = "HIPAA-Ready"
    CostCenter  = "GenomicsInfra"
    Note        = "Deploy per-AZ in production for HA and cost optimization"
  }

  depends_on = [aws_internet_gateway.igw]
}

# =============================================================================
# 8. Private Route Table — Routes Outbound Traffic Through NAT Gateway
# =============================================================================
# PURPOSE: Directs all non-local traffic (0.0.0.0/0) from private subnets
# through the NAT Gateway. Without this route, private subnet resources
# have no outbound path — correct for isolation, incorrect for patching.
#
# HIPAA RELEVANCE: Outbound-only egress satisfies the principle that genomic
# compute nodes are not directly addressable from the internet while still
# receiving OS and software updates from AWS package repositories.
# =============================================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.genomics.id

  # Only add NAT route when NAT Gateway is deployed
  dynamic "route" {
    for_each = aws_nat_gateway.primary
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = route.value.id
    }
  }

  tags = {
    Name        = "Genomics-Private-RT"
    Environment = var.environment
    Compliance  = "HIPAA-Ready"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
# =============================================================================
# Module Outputs
# =============================================================================

output "vpc_id" {
  description = "Genomics VPC ID"
  value       = aws_vpc.genomics.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for compute placement"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "public_subnet_ids" {
  description = "Public subnet IDs for load balancers and NAT"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}
