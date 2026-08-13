# =============================================================================
# 1. IAM Role for EC2 (SSM & S3 Access)
# =============================================================================
resource "aws_iam_role" "ec2_ssm_role" {
  name = "Genomics-Practice-EC2-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for Systems Manager (so you can connect without an SSH Key)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach ReadOnly access to S3 for genomic data simulation
resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "Genomics-Practice-EC2-Profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# =============================================================================
# 2. Security Group for Isolated Compute
# =============================================================================
resource "aws_security_group" "private_sg" {
  name        = "genomics-private-sg"
  description = "Security group for private genomics compute instances"
  vpc_id      = module.networking.vpc_id # References your existing VPC module output

  # Egress: Allow outbound HTTPS to VPC Endpoints / Systems Manager
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "Genomics-Private-SG"
    Compliance = "HIPAA-Ready"
  }
}

# =============================================================================
# 3. Low-Cost Private EC2 Instance (t3.nano)
# =============================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "private_compute" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.nano"                               # Costs ~$0.0052/hour
  subnet_id              = module.networking.private_subnet_ids[0] # Places it in Private Subnet A
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforces IMDSv2 (HIPAA/Security best practice)
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "Genomics-Isolated-Compute"
    Environment = "Dev-Sandbox"
    Compliance  = "HIPAA-Ready"
  }
}
