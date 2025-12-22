# Subnet Layout for BYO VPC Multi-Cluster Example
# ================================================
#
# This example creates subnets for two EKS clusters in an existing VPC.
# Adjust the CIDR ranges to fit your VPC's available address space.
#
# Example Layout (using /22 = 1024 IPs for private, /24 = 256 IPs for public):
#   Cluster 1 (Control):
#     Private AZ-a: 10.0.32.0/22
#     Private AZ-b: 10.0.36.0/22
#     Public AZ-a:  10.0.48.0/24
#     Public AZ-b:  10.0.49.0/24
#
#   Cluster 2 (Deployments):
#     Private AZ-a: 10.0.40.0/22
#     Private AZ-b: 10.0.44.0/22
#     Public AZ-a:  10.0.50.0/24
#     Public AZ-b:  10.0.51.0/24

# -----------------------------------------------------------------------------
# Variables - Update these for your environment
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of existing VPC to create subnets in"
  type        = string
}

variable "private_route_table_id" {
  description = "Route table ID with NAT Gateway for private subnets"
  type        = string
}

variable "public_route_table_id" {
  description = "Route table ID with Internet Gateway for public subnets"
  type        = string
}

variable "control_cluster_name" {
  description = "Name for the control plane cluster"
  type        = string
  default     = "control"
}

variable "deployments_cluster_name" {
  description = "Name for the deployments cluster"
  type        = string
  default     = "deployments"
}

# -----------------------------------------------------------------------------
# Subnet CIDR Configuration - Update for your VPC
# -----------------------------------------------------------------------------

locals {
  # Control cluster subnets
  control_private_subnets = {
    "${local.region}a" = "10.0.32.0/22"
    "${local.region}b" = "10.0.36.0/22"
  }
  control_public_subnets = {
    "${local.region}a" = "10.0.48.0/24"
    "${local.region}b" = "10.0.49.0/24"
  }

  # Deployments cluster subnets
  deployments_private_subnets = {
    "${local.region}a" = "10.0.40.0/22"
    "${local.region}b" = "10.0.44.0/22"
  }
  deployments_public_subnets = {
    "${local.region}a" = "10.0.50.0/24"
    "${local.region}b" = "10.0.51.0/24"
  }
}

# -----------------------------------------------------------------------------
# Control Cluster Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "control_private" {
  for_each = local.control_private_subnets

  vpc_id            = var.vpc_id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name                              = "${var.control_cluster_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.control_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "control_public" {
  for_each = local.control_public_subnets

  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.control_cluster_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.control_cluster_name}" = "shared"
  }
}

# -----------------------------------------------------------------------------
# Deployments Cluster Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "deployments_private" {
  for_each = local.deployments_private_subnets

  vpc_id            = var.vpc_id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name                              = "${var.deployments_cluster_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.deployments_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "deployments_public" {
  for_each = local.deployments_public_subnets

  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.deployments_cluster_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.deployments_cluster_name}" = "shared"
  }
}

# -----------------------------------------------------------------------------
# Route Table Associations
# -----------------------------------------------------------------------------

resource "aws_route_table_association" "control_private" {
  for_each       = aws_subnet.control_private
  subnet_id      = each.value.id
  route_table_id = var.private_route_table_id
}

resource "aws_route_table_association" "control_public" {
  for_each       = aws_subnet.control_public
  subnet_id      = each.value.id
  route_table_id = var.public_route_table_id
}

resource "aws_route_table_association" "deployments_private" {
  for_each       = aws_subnet.deployments_private
  subnet_id      = each.value.id
  route_table_id = var.private_route_table_id
}

resource "aws_route_table_association" "deployments_public" {
  for_each       = aws_subnet.deployments_public
  subnet_id      = each.value.id
  route_table_id = var.public_route_table_id
}

# -----------------------------------------------------------------------------
# Outputs for cluster modules
# -----------------------------------------------------------------------------

output "control_private_subnet_ids" {
  value = [for s in aws_subnet.control_private : s.id]
}

output "control_public_subnet_ids" {
  value = [for s in aws_subnet.control_public : s.id]
}

output "deployments_private_subnet_ids" {
  value = [for s in aws_subnet.deployments_private : s.id]
}

output "deployments_public_subnet_ids" {
  value = [for s in aws_subnet.deployments_public : s.id]
}
