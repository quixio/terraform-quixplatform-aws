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

  # For EFS mount targets: use subnet IDs as keys (known at plan time)
  # This avoids the for_each unknown key issue when using BYO VPC
  # When singleaz is set, EFS is OneZone and needs only one mount target
  # For BYO VPC with singleaz, user must pass only the desired subnet(s)
  efs_mount_subnet_ids = var.create_vpc ? (
    var.singleaz != null ? [module.vpc[0].private_subnets[index(module.vpc[0].azs, var.singleaz)]] : module.vpc[0].private_subnets
  ) : var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Location    = var.region
      ClusterName = var.cluster_name
    }
  )
}
