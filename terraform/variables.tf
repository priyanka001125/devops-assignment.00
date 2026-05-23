variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.20.0.0/16"
}

variable "environment" {
  default = "staging"
}

variable "ssh_allowed_cidr" {
  description = "⚠️ INSECURE - For demo only. Production should restrict to VPN/Bastion IP"
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "project_name" {
  default = "nimbuskart"
}