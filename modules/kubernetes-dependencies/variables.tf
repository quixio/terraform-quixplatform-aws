################################################################################
# Cluster Configuration
################################################################################

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region where the cluster lives"
  type        = string
}

variable "amazon_container_id" {
  description = "AWS account id hosting the EKS public ECR images"
  type        = string
  default     = "602401143452"
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default = {
    Environment = "Production"
    Customer    = "Quix"
  }
}

################################################################################
# Network Plugin (Calico)
################################################################################

variable "enable_calico" {
  description = "Deploy Calico via Helm for network policy enforcement"
  type        = bool
  default     = true
}

################################################################################
# AWS Load Balancer Controller Configuration
################################################################################

variable "enable_aws_load_balancer_controller" {
  description = "Deploy the AWS Load Balancer Controller via Helm"
  type        = bool
  default     = true
}

variable "nlb_controller_namespace" {
  description = "Namespace for the AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

variable "nlb_controller_service_account" {
  description = "Service account used by the AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "nlb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  type        = string
  default     = null
}

################################################################################
# EFS CSI Driver Configuration
################################################################################

variable "enable_efs_csi_addon" {
  description = "Deploy the EFS CSI driver via Helm"
  type        = bool
  default     = true
}

variable "efs_csi_namespace" {
  description = "Namespace for the EFS CSI controller"
  type        = string
  default     = "kube-system"
}

variable "efs_csi_service_account" {
  description = "Service account name for the EFS CSI controller"
  type        = string
  default     = "efs-csi-controller-sa"
}

variable "efs_csi_role_arn" {
  description = "IAM role ARN for the EFS CSI controller"
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for the EKS cluster"
  type        = string
  default     = null
}

variable "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  type        = string
  default     = null
}

################################################################################
# EFS StorageClass Configuration
################################################################################

variable "create_efs_storage_class" {
  description = "Whether to create the EFS storage class"
  type        = bool
  default     = true
}

variable "efs_storage_class_name" {
  description = "Name of the EFS storage class"
  type        = string
  default     = "efs-sc"
}

variable "efs_storage_class_reclaim_policy" {
  description = "Reclaim policy for the EFS storage class (Retain or Delete)"
  type        = string
  default     = "Retain"
}

variable "efs_file_system_id" {
  description = "ID of the backing EFS file system"
  type        = string
  default     = null
}

################################################################################
# EBS StorageClass Configuration
################################################################################

variable "create_ebs_storage_class" {
  description = "Whether to create the EBS storage class"
  type        = bool
  default     = true
}

variable "ebs_storage_class_name" {
  description = "Name of the EBS storage class"
  type        = string
  default     = "gp3"
}

variable "ebs_storage_class_is_default" {
  description = "Whether to mark the EBS storage class as default"
  type        = bool
  default     = true
}

variable "ebs_storage_class_reclaim_policy" {
  description = "Reclaim policy for the EBS storage class (Retain or Delete)"
  type        = string
  default     = "Delete"
}

variable "ebs_storage_class_volume_binding_mode" {
  description = "Volume binding mode for the EBS storage class (Immediate or WaitForFirstConsumer)"
  type        = string
  default     = "WaitForFirstConsumer"
}

variable "ebs_storage_class_allow_volume_expansion" {
  description = "Whether volumes from the EBS storage class support expansion"
  type        = bool
  default     = true
}

variable "ebs_volume_type" {
  description = "EBS volume type for the storage class (gp2, gp3, io1, etc.)"
  type        = string
  default     = "gp3"
}
