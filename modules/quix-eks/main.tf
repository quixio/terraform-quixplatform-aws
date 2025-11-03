data "aws_caller_identity" "current" {}


locals {
  # Calculate AZs based on whether we're creating VPC or using existing
  azs = var.create_vpc ? slice(data.aws_availability_zones.available.names, 0, var.azs) : (
    distinct([for subnet in data.aws_subnet.existing_private : subnet.availability_zone])
  )

  # Map private subnets by AZ (one subnet per AZ)
  # When using existing VPC, if multiple subnets exist in same AZ, we take the first one
  private_subnets_by_az = var.create_vpc ? {
    for index, az in module.vpc[0].azs : az => module.vpc[0].private_subnets[index]
    } : {
    for subnet in data.aws_subnet.existing_private : subnet.availability_zone => subnet.id
  }

  tags = merge(
    var.tags,
    {
      Location    = var.region
      ClusterName = var.cluster_name
    }
  )
}
