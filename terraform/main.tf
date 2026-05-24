# ============================================
# USING NETWORK MODULE (Reusable)
# ============================================

module "network" {
  source = "./modules/network"

  vpc_cidr           = var.vpc_cidr
  project_name       = var.project_name
  subnet_count       = 2
  availability_zones = ["us-east-1a", "us-east-1b"]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
  }
}

# ============================================
# SECURITY GROUP
# ============================================

resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = module.network.vpc_id

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
  }

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # ⚠️ SSH - INSECURE DEFAULT (Flagged in README)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
    description = "SSH - INSECURE DEFAULT - Flagged"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================
# EC2 INSTANCES (Web Tier)
# ============================================

resource "aws_instance" "web" {
  count                  = 2
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = var.instance_type
  subnet_id              = module.network.subnet_ids[count.index % 2]
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

# ============================================
# S3 BUCKET FOR LOGS
# ============================================

resource "aws_s3_bucket" "logs" {
  bucket = "nimbuskart-logs-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "engineering"
    ManagedBy   = "terraform"
  }
}

# Versioning enabled
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle rule - expire non-current versions after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ============================================
# INTENTIONAL ORPHAN - Unattached EBS Volume
# ============================================

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