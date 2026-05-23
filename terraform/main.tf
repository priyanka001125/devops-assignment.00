# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering@nimbuskart.com"
    ManagedBy   = "terraform"
  }
}

# Public subnets (2 AZs)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = count.index == 0 ? "us-east-1a" : "us-east-1b"

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
  }
}

# Security Group (⚠️ Port 22 open to 0.0.0.0/0 is unsafe - flagged)
resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # ⚠️ INSECURE DEFAULT - Flagged in README
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
    description = "SSH - INSECURE DEFAULT"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instances
resource "aws_instance" "web" {
  count                  = 2
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index % 2].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name        = "web-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
    Tier        = "web"
  }
}

# S3 bucket for logs
resource "aws_s3_bucket" "logs" {
  bucket = "nimbuskart-logs-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# INTENTIONAL ORPHAN - Unattached EBS volume
resource "aws_ebs_volume" "orphan" {
  availability_zone = "us-east-1a"
  size              = 20
  type              = "gp3"

  tags = {
    Name        = "orphan-volume-do-not-attach"
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
  }
}