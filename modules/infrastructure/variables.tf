variable "region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
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
  description = "Docker image URI"
  type        = string
  default     = ""
}

variable "tags_common" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "create_ecr" {
  description = "Si true, crea el ECR; si false, se asume existente y solo se consulta"
  type        = bool
  default     = false
}

variable "ecr_repository_name" {
  description = "Nombre del repositorio ECR (existente o a crear si create_ecr=true)"
  type        = string
  default     = "umma-dev-aws-app"
}
