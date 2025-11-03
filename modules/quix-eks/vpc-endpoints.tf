################################################################################
# VPC Endpoints
################################################################################

module "vpc_endpoints" {
  count   = var.create_s3_endpoint ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = local.vpc_id

  endpoints = {
    s3_gateway = {
      # gateway endpoint
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
