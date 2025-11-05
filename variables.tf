variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production"
  }
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "aws-oaxaca"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "demo"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.64.0.0/20"
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_name" {
  description = "Database name"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "docker_image" {
  description = "Docker image URI (registry/repo@digest or registry/repo:tag)"
  type        = string
  default     = ""
}

variable "tags_common" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "aws-ug-oaxaca"
    Environment = "development"
    Owner       = "Pablo Galeana Bailey"
    ManagedBy   = "Terraform"
  }
}