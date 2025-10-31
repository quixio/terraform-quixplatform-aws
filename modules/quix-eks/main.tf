data "aws_caller_identity" "current" {}


locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.azs) #"eucentral0-a and eucentral0-b"
  private_subnets_by_az = {
    for index, az in module.vpc.azs : az => module.vpc.private_subnets[index]
  }
  tags = merge(
    var.tags,
    {
      Location    = var.region
      ClusterName = var.cluster_name
    }
  )
}
