#############################################
# Terraform Backend (S3 + DynamoDB)
#############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-k3s-terraform-state-bkt"
    key            = "k3s/terraform.tfstate"
    region         = "ap-south-1"
    use_lockfile   = "true"
  }
}

#############################################
# Provider
#############################################

provider "aws" {
  region = var.region
}

#############################################
# Security Group (Ingress-based)
#############################################

resource "aws_security_group" "k3s_sg" {
  name        = "k3s-ingress-sg"
  description = "Allow HTTP (Ingress) and SSH"

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP (Ingress via Traefik)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional (HTTPS if you extend later)
  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############################################
# EC2 Instance (k3s Setup)
#############################################

resource "aws_instance" "k3s_server" {
  ami           = "ami-0f58b397bc5c1f2e8"
  instance_type = "t3.small"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y curl

              # Install k3s (comes with Traefik Ingress)
              curl -sfL https://get.k3s.io | sh -

              # Make kubeconfig readable
              chmod 644 /etc/rancher/k3s/k3s.yaml
              EOF

  tags = {
    Name = "k3s-server"
  }
}

#############################################
# Outputs
#############################################

output "instance_public_ip" {
  value = aws_instance.k3s_server.public_ip
}

output "app_url" {
  value = "http://${aws_instance.k3s_server.public_ip}"
}