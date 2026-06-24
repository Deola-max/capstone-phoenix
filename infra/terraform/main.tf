terraform {
  backend "s3" {
    bucket         = "favour-lambe-phoenix-k8s-state-bucket" # MUST be unique globally on AWS
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "phoenix-k8s-state-locks"
    encrypt        = true
  }
}
provider "aws" {
  region = var.aws_region
}

# Create Custom VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "phoenix-k8s-vpc" }
}

resource "aws_subnet" "k8s_public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                 = { Name = "phoenix-k8s-public-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags   = { Name = "phoenix-gw" }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.k8s_public_subnet.id
  route_table_id = aws_route_table.rt.id
}

# Least-Privilege Firewall (Hard Constraint!)
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-cluster-sg"
  description = "Allow web traffic and highly restricted SSH"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_public_ip]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "Allow Kubernetes API Server from my IP"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_public_ip]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Compute Instances (1 Control Plane Server + 2 Worker Agents)
resource "aws_instance" "control_plane" {
  ami                    = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.k8s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = "adeola-key"
 # CHANGE TO YOUR ACTUAL AWS KEY PAIR NAME

  tags = { Name = "k3s-control-plane" }
}

resource "aws_instance" "worker" {
  count                  = 2
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.k8s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = "adeola-key" # CHANGE TO YOUR ACTUAL AWS KEY PAIR NAME

  tags = { Name = "k3s-worker-${count.index + 1}" }
}


