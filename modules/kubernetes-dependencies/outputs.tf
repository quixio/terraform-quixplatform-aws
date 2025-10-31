################################################################################
# EFS related outputs
################################################################################

output "efs_csi_enabled" {
  description = "Whether the EFS CSI driver was enabled"
  value       = var.enable_efs_csi_addon
}

output "efs_csi_helm_release_name" {
  description = "Name of the EFS CSI driver Helm release"
  value       = try(helm_release.efs_csi[0].name, null)
}

output "efs_csi_namespace" {
  description = "Namespace where the EFS CSI driver is installed"
  value       = var.efs_csi_namespace
}

output "efs_storage_class_name" {
  description = "Name of the EFS storage class if created"
  value       = try(kubernetes_storage_class_v1.efs[0].metadata[0].name, null)
}

output "efs_storage_class_provisioner" {
  description = "Storage provisioner used by the EFS storage class"
  value       = try(kubernetes_storage_class_v1.efs[0].storage_provisioner, null)
}

################################################################################
# EBS related outputs
################################################################################

output "ebs_storage_class_enabled" {
  description = "Whether the EBS storage class was created"
  value       = var.create_ebs_storage_class
}

output "ebs_storage_class_name" {
  description = "Name of the EBS storage class if created"
  value       = try(kubernetes_storage_class_v1.ebs[0].metadata[0].name, null)
}

output "ebs_storage_class_is_default" {
  description = "Whether the EBS storage class is set as default"
  value       = var.ebs_storage_class_is_default
}

output "ebs_storage_class_provisioner" {
  description = "Storage provisioner used by the EBS storage class"
  value       = try(kubernetes_storage_class_v1.ebs[0].storage_provisioner, null)
}

output "ebs_storage_class_volume_type" {
  description = "EBS volume type configured in the storage class"
  value       = var.ebs_volume_type
}

################################################################################
# Cluster information
################################################################################

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
}

output "cluster_region" {
  description = "AWS region where the cluster is located"
  value       = var.region
}

################################################################################
# AWS Load Balancer Controller outputs
################################################################################

output "nlb_controller_enabled" {
  description = "Whether the AWS Load Balancer Controller was enabled"
  value       = var.enable_aws_load_balancer_controller
}

output "nlb_controller_namespace" {
  description = "Namespace where the AWS Load Balancer Controller is installed"
  value       = var.nlb_controller_namespace
}

output "nlb_controller_service_account" {
  description = "Service account used by the AWS Load Balancer Controller"
  value       = var.nlb_controller_service_account
}

################################################################################
# Module metadata
################################################################################

output "module_tags" {
  description = "Tags applied to resources created by this module"
  value       = local.tags
}
