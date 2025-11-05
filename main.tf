terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.92.0, < 6.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
  }
}


provider "aws" {
  region = var.region

  default_tags {
    tags = merge(
      var.tags_common,
      {
        ManagedBy   = "Terraform"
        Environment = var.environment
        Project     = var.project
      }
    )
  }
}

module "infrastructure" {
  source = "./modules/infrastructure"

  # Básico
  region      = var.region
  environment = var.environment
  name_prefix = var.name_prefix
  project     = var.project

  # Red
  vpc_cidr          = var.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs

  # DB
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # EC2
  instance_type = var.instance_type
  docker_image  = var.docker_image

  # Tags
  tags_common = var.tags_common
}

# Outputs
output "ec2_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = module.infrastructure.ec2_public_ip
}

output "ec2_public_dns" {
  description = "DNS público de la instancia EC2"
  value       = module.infrastructure.ec2_public_dns
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2"
  value       = module.infrastructure.ec2_instance_id
}

output "rds_endpoint" {
  description = "Endpoint de RDS (sensitive)"
  value       = module.infrastructure.rds_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "Puerto de RDS"
  value       = module.infrastructure.rds_port
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR"
  value       = module.infrastructure.ecr_repository_url
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.infrastructure.vpc_id
}

output "application_url" {
  description = "URL de la aplicación"
  value       = "http://${module.infrastructure.ec2_public_ip}"
}
