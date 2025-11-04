output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "command_output" {
  description = "The output of the aws command"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = var.create_vpc ? var.vpc_cidr : data.aws_vpc.existing[0].cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = local.private_subnet_ids
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = local.public_subnet_ids
}

################################################################################
# VPC Endpoints Outputs
################################################################################

output "vpc_endpoints" {
  description = "Array containing the full resource object and attributes for all endpoints created"
  value       = var.create_s3_endpoint ? module.vpc_endpoints[0].endpoints : null
}

################################################################################
# Route 53 Outputs
################################################################################

output "route53_zone_id" {
  description = "The hosted zone ID"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : null
}

output "route53_zone_name_servers" {
  description = "The name servers for the hosted zone"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].name_servers : null
}

output "route53_zone_arn" {
  description = "The Amazon Resource Name (ARN) of the Hosted Zone"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].arn : null
}

################################################################################
# Cert Manager Outputs
################################################################################

output "cert_manager_role_arn" {
  description = "ARN of the cert-manager IAM role"
  value       = var.create_cert_manager_role ? aws_iam_role.cert_manager[0].arn : null
}

output "cert_manager_policy_arn" {
  description = "ARN of the cert-manager Route53 policy"
  value       = var.create_cert_manager_role ? aws_iam_policy.cert_manager_route53[0].arn : null
}

output "cert_manager_service_account_annotation" {
  description = "Annotation to add to the cert-manager service account"
  value = var.create_cert_manager_role ? {
    "eks.amazonaws.com/role-arn" = aws_iam_role.cert_manager[0].arn
  } : null
}


################################################################################
# EBS related outputs
################################################################################

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver (if created)"
  value       = aws_iam_role.ebs_csi.arn
}

################################################################################
# EFS related outputs
################################################################################

output "efs_file_system_id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.this.id
}

output "efs_file_system_arn" {
  description = "The ARN of the EFS file system"
  value       = aws_efs_file_system.this.arn
}

output "efs_file_system_dns_name" {
  description = "The DNS name of the EFS file system"
  value       = aws_efs_file_system.this.dns_name
}

################################################################################
# EKS OIDC outputs
################################################################################

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

