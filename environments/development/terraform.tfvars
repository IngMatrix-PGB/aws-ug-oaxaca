region            = "us-east-1"
project           = "aws"
vpc_cidr          = "10.64.0.0/20"
allowed_ssh_cidrs = ["0.0.0.0/0"]

db_name     = "appdb"
db_username = "postgres"
db_password = "ChangeMe123!"

name_prefix   = "umma"
instance_type = "t3.micro"
environment   = "development"

tags_common = {
  Project     = "aws-ug-oaxaca"
  Environment = "development"
  Owner       = "Pablo Galeana Bailey"
  ManagedBy   = "Terraform"
}

# CI/CD sobreescribe esto con -var "docker_image=REGISTRY/REPO@sha256:..."
docker_image = ""
