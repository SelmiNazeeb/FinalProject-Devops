# main.tf
terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
        }
    }
    }
# Configure the AWS Provider
provider "aws" {
    region = var.my_region
}
#############################
# VPC and Networking
#############################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Public Subnets

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name                  = "${var.cluster_name}-public-subnet-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name                      = "${var.cluster_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Public Route Table and routes

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway and EIP

resource "aws_eip" "nat" {
  vpc = true
  depends_on = [aws_internet_gateway.this]
  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "${var.cluster_name}-nat-gateway"
  }
}

# Private Route Table

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

#############################
# Security Groups
#############################

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS control plane communication"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name                               = "${var.cluster_name}-cluster-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group" "eks_node" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS worker nodes SG"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.cluster_name}-node-sg"
  }
}

# SG ingress rules

resource "aws_security_group_rule" "eks_cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group_rule" "eks_node_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_node.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "eks_node_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_node.id
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group" "db" {
  name        = "${var.db_instance_identifier}-sg"
  description = "RDS access SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    security_groups          = [aws_security_group.eks_node.id]
  }

  tags = {
    Name = "${var.db_instance_identifier}-sg"
  }
}

#############################
# IAM Roles and Policies
#############################

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.db_instance_identifier}-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  ]
}

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ]
}

resource "aws_iam_role" "eks_node_group" {
  name = "${var.cluster_name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ]
}

#############################
# RDS Subnet Group and Instance
#############################

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_instance_identifier}-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name    = "${var.db_instance_identifier}-subnet-group"
    Project = "CloudOps-Demo"
  }
}

resource "aws_db_instance" "this" {
  identifier              = var.db_instance_identifier
  engine                  = "postgres"
  engine_version          = "15.13"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  publicly_accessible     = false
  multi_az                = false
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  monitoring_role_arn     = aws_iam_role.rds_enhanced_monitoring.arn
  monitoring_interval     = 60
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 7
  backup_window           = "03:00-06:00"
  maintenance_window      = "sun:00:00-sun:04:00"

  tags = {
    Name = var.db_instance_identifier
  }
}

#############################
# EKS Cluster and Node Group
#############################

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = ">= 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  subnets         = aws_subnet.private[*].id
  vpc_id          = aws_vpc.this.id

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  manage_aws_auth = true

  cluster_security_group_id = aws_security_group.eks_cluster.id
  node_security_group_ids   = [aws_security_group.eks_node.id]

  node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_types   = ["t3.medium"]
      key_name         = var.key_name

      iam_role_arn = aws_iam_role.eks_node_group.arn

      subnet_ids = aws_subnet.private[*].id
    }
  }

  tags = {
    Environment = "demo"
    Project     = "CloudOps-Demo"
  }
}

#############################
# Outputs
#############################


