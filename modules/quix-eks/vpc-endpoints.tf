################################################################################
# VPC Endpoints
################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3_gateway = {
      # gateway endpoint
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
      tags            = { Name = "${var.cluster_name}-s3-gateway-endpoint" }
    }
  }

  tags = merge(local.tags, {
    Project = "${var.cluster_name}-vpc-endpoints"
  })
}
