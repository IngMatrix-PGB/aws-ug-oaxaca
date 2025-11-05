terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


# ============================================================================
# Locals
# ============================================================================
locals {
  env_short = (
    var.environment == "production" ? "prd" :
    var.environment == "staging" ? "stg" : "dev"
  )

  base_name = lower(join("-", compact([var.name_prefix, local.env_short, var.project])))

  default_tags = merge(var.tags_common, {
    Name        = local.base_name
    Environment = var.environment
    Project     = var.project
  })

  # Subnets
  public_subnets = [
    cidrsubnet(var.vpc_cidr, 5, 0),
    cidrsubnet(var.vpc_cidr, 5, 1),
    cidrsubnet(var.vpc_cidr, 5, 2),
  ]

  private_subnets = [
    cidrsubnet(var.vpc_cidr, 5, 3),
    cidrsubnet(var.vpc_cidr, 5, 4),
    cidrsubnet(var.vpc_cidr, 5, 5),
  ]

  # -------- NUEVO: resolver URL del repo y la imagen por defecto --------
  ecr_repo_url = var.create_ecr ? aws_ecr_repository.this[0].repository_url : data.aws_ecr_repository.existing[0].repository_url

  default_image = "${local.ecr_repo_url}:latest"

  # User Data template (nota: docker_image puede venir por var o default a :latest)
  user_data_raw = templatefile("${path.module}/user-data.sh.tmpl", {
    aws_account_id = data.aws_caller_identity.current.account_id
    aws_region     = var.region
    ecr_repository = var.create_ecr ? aws_ecr_repository.this[0].name : data.aws_ecr_repository.existing[0].name
    docker_image   = var.docker_image != "" ? var.docker_image : local.default_image
  })
  user_data_b64 = base64encode(local.user_data_raw)
}


# ============================================================================
# Data Sources
# ============================================================================
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# AMI más reciente de Amazon Linux 2023
data "aws_ssm_parameter" "al2023_x86" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# ============================================================================
# VPC
# ============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.9"

  name = "${local.base_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "development" ? true : false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    Type = "public"
  }

  private_subnet_tags = {
    Type = "private"
  }

  tags = local.default_tags
}

# ============================================================================
# Security Groups
# ============================================================================
resource "aws_security_group" "ec2_sg" {
  name        = "${local.base_name}-ec2-sg"
  description = "Security group for EC2 instance - HTTP/SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.allowed_ssh_cidrs
    content {
      description = "SSH from ${ingress.value}"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${local.base_name}-ec2-sg"
  })
}

module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.base_name}-rds-sg"
  description = "Security group for RDS - PostgreSQL access from EC2 only"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [{
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    description              = "PostgreSQL from EC2"
    source_security_group_id = aws_security_group.ec2_sg.id
  }]

  egress_rules = ["all-all"]

  tags = merge(local.default_tags, {
    Name = "${local.base_name}-rds-sg"
  })
}

# ============================================================================
# IAM
# ============================================================================
module "iam_ec2_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.34"

  create_role           = true
  role_requires_mfa     = false
  role_name             = "${local.base_name}-ec2-role"
  role_description      = "IAM role for EC2 to pull from ECR and use SSM"
  trusted_role_services = ["ec2.amazonaws.com"]

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_readonly" {
  role       = module.iam_ec2_role.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = module.iam_ec2_role.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.base_name}-ec2-profile"
  role = module.iam_ec2_role.iam_role_name

  tags = local.default_tags
}

data "aws_ecr_repository" "existing" {
  count = var.create_ecr ? 0 : 1
  name  = var.ecr_repository_name
}

# ============================================================================
# ECR
# ============================================================================
resource "aws_ecr_repository" "this" {
  count                = var.create_ecr ? 1 : 0
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }

  tags = merge(local.default_tags, { Name = "${local.base_name}-ecr" })
}

resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.create_ecr ? 1 : 0
  repository = aws_ecr_repository.this[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 images"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
        action       = { type = "expire" }
      }
    ]
  })
}


# ============================================================================
# EC2
# ============================================================================
module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "< 6.0"

  name = "${local.base_name}-ec2"

  ami                         = data.aws_ssm_parameter.al2023_x86.value
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data_base64            = local.user_data_b64
  user_data_replace_on_change = true

  # Metadata options (IMDSv2)
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # Root volume
  root_block_device = [
    {
      volume_type = "gp3"
      volume_size = 8
      encrypted   = true
      throughput  = 125
      iops        = 3000
    }
  ]

  enable_volume_tags = true
  volume_tags        = local.default_tags

  tags = local.default_tags
}

# ============================================================================
# RDS
# ============================================================================
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "< 6.0"

  identifier = "${local.base_name}-pg"

  engine               = "postgres"
  engine_version       = "16.3"
  family               = "postgres16"
  major_engine_version = "16"

  instance_class = var.environment == "production" ? "db.t3.micro" : "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = var.environment == "production" ? 100 : 50
  storage_encrypted     = true
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network
  vpc_security_group_ids = [module.rds_sg.security_group_id]
  subnet_ids             = module.vpc.private_subnets
  create_db_subnet_group = true
  publicly_accessible    = false

  # Backup
  backup_retention_period = var.environment == "production" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # High Availability (solo producción)
  multi_az = var.environment == "production"

  # Misc
  skip_final_snapshot = var.environment != "production"
  deletion_protection = var.environment == "production"

  # Nota: final_snapshot_identifier se maneja automáticamente por el módulo
  # cuando skip_final_snapshot = false

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = var.environment == "production" ? 60 : 0
  monitoring_role_arn             = var.environment == "production" ? aws_iam_role.rds_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled          = var.environment == "production"
  performance_insights_retention_period = var.environment == "production" ? 7 : null

  tags = merge(local.default_tags, {
    Name = "${local.base_name}-rds"
  })
}

# IAM Role para RDS Enhanced Monitoring (solo producción)
resource "aws_iam_role" "rds_monitoring" {
  count = var.environment == "production" ? 1 : 0

  name = "${local.base_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.environment == "production" ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
