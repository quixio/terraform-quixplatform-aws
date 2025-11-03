
################################################################################
# VPC
################################################################################
data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Data sources for existing VPC (when create_vpc is false)
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnet" "existing_private" {
  count = var.create_vpc ? 0 : length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

data "aws_subnet" "existing_public" {
  count = var.create_vpc ? 0 : length(var.public_subnet_ids)
  id    = var.public_subnet_ids[count.index]
}

data "aws_route_tables" "existing_private" {
  count  = var.create_vpc ? 0 : 1
  vpc_id = var.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_route_tables" "existing_public" {
  count  = var.create_vpc ? 0 : 1
  vpc_id = var.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

# Create new VPC (when create_vpc is true)
module "vpc" {
  count   = var.create_vpc ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-net"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway    = var.enable_nat_gateway
  single_nat_gateway    = true
  private_subnet_suffix = "private"
  public_subnet_suffix  = "public"
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

# Local values to unify VPC resources
locals {
  vpc_id             = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
  public_subnet_ids  = var.create_vpc ? module.vpc[0].public_subnets : var.public_subnet_ids

  # Route table IDs for VPC endpoints
  private_route_table_ids = var.create_vpc ? module.vpc[0].private_route_table_ids : (
    length(data.aws_route_tables.existing_private) > 0 ? data.aws_route_tables.existing_private[0].ids : []
  )
  public_route_table_ids = var.create_vpc ? module.vpc[0].public_route_table_ids : (
    length(data.aws_route_tables.existing_public) > 0 ? data.aws_route_tables.existing_public[0].ids : []
  )
}
