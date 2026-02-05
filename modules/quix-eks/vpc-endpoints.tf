################################################################################
# VPC Endpoints
################################################################################

# Security group for Interface endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.create_private_eks_endpoints ? 1 : 0

  name        = "${var.cluster_name}-vpc-endpoints-sg"
  description = "Security group for VPC Interface endpoints"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-vpc-endpoints-sg"
  })
}

# S3 Gateway endpoint (free, no hourly charge)
module "vpc_endpoints_gateway" {
  count   = var.create_s3_endpoint ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.17.0"

  vpc_id = local.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([local.private_route_table_ids, local.public_route_table_ids])
      tags            = { Name = "${var.cluster_name}-s3-gateway-endpoint" }
    }
  }

  tags = merge(local.tags, {
    Project = "${var.cluster_name}-vpc-endpoints"
  })
}

# Interface endpoints for private EKS clusters
module "vpc_endpoints_interface" {
  count   = var.create_private_eks_endpoints ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.17.0"

  vpc_id = local.vpc_id

  endpoints = {
    ecr_api = {
      service             = "ecr.api"
      service_type        = "Interface"
      subnet_ids          = local.private_subnet_ids
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
      tags                = { Name = "${var.cluster_name}-ecr-api-endpoint" }
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      service_type        = "Interface"
      subnet_ids          = local.private_subnet_ids
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
      tags                = { Name = "${var.cluster_name}-ecr-dkr-endpoint" }
    }
    sts = {
      service             = "sts"
      service_type        = "Interface"
      subnet_ids          = local.private_subnet_ids
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
      tags                = { Name = "${var.cluster_name}-sts-endpoint" }
    }
    ec2 = {
      service             = "ec2"
      service_type        = "Interface"
      subnet_ids          = local.private_subnet_ids
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
      tags                = { Name = "${var.cluster_name}-ec2-endpoint" }
    }
    logs = {
      service             = "logs"
      service_type        = "Interface"
      subnet_ids          = local.private_subnet_ids
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
      tags                = { Name = "${var.cluster_name}-logs-endpoint" }
    }
  }

  tags = merge(local.tags, {
    Project = "${var.cluster_name}-vpc-endpoints"
  })
}
