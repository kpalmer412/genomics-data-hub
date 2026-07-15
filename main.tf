terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "ken-genomics-tfstate-2026"
    key     = "dev/genomics-data-hub.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project    = "Genomics-Data-Hub"
      ManagedBy  = "Terraform"
      Compliance = "HIPAA-Ready"
    }
  }
}

module "networking" {
  source      = "./modules/networking"
  vpc_cidr    = var.vpc_cidr
  environment = var.environment
}
