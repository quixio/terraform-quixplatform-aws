################################################################################
# EKS
################################################################################

################################################################################
# File System
################################################################################

resource "aws_efs_file_system" "this" {

  #availability_zone_name          = var.azs
  creation_token         = var.creation_token
  throughput_mode        = "elastic"
  encrypted              = var.encrypted
  availability_zone_name = var.singleaz

  dynamic "lifecycle_policy" {
    for_each = length(var.lifecycle_policy) > 0 ? [var.lifecycle_policy] : []
    content {
      transition_to_ia                    = try(lifecycle_policy.value.transition_to_ia, null)
      transition_to_primary_storage_class = try(lifecycle_policy.value.transition_to_primary_storage_class, null)
    }
  }

  tags = merge(
    local.tags,
    {
      Location = var.region
      Name     = "${var.cluster_name}-efs"
    }
  )
}



################################################################################
# Mount Target(s)
################################################################################

resource "aws_efs_mount_target" "this" {
  # Use AZ names (known at plan) as keys; pick one subnet per AZ at apply
  for_each = var.singleaz == null ? { for az in local.azs : az => true } : { for az in [var.singleaz] : az => true }

  file_system_id  = aws_efs_file_system.this.id
  security_groups = [module.eks.cluster_primary_security_group_id, module.eks.node_security_group_id]
  subnet_id       = local.private_subnets_by_az[each.key]
}




################################################################################
# Backup Policy
################################################################################

resource "aws_efs_backup_policy" "this" {
  count = var.create_backup_policy ? 1 : 0

  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = var.enable_backup_policy ? "ENABLED" : "DISABLED"
  }
}

################################################################################
# Replication Configuration
################################################################################

resource "aws_efs_replication_configuration" "this" {
  count = var.create_replication_configuration ? 1 : 0

  source_file_system_id = aws_efs_file_system.this.id

  dynamic "destination" {
    for_each = [var.replication_configuration_destination]

    content {
      availability_zone_name = try(destination.value.availability_zone_name, null)
      kms_key_id             = try(destination.value.kms_key_id, null)
      region                 = try(destination.value.region, null)
    }
  }
}



