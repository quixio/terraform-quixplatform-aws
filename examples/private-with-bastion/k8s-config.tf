# This file contains the Kubernetes configuration that must be executed
# FROM THE BASTION, as it requires access to the cluster's private API.
#
# To use it:
# 1. Comment this file in the initial apply (or use -target to create only EKS)
# 2. After creating the bastion, connect to it
# 3. Copy this code to the bastion and execute it from there

################################################################################
# NOTE: This block should be uncommented ONLY when running from the bastion
################################################################################

# Uncomment when you are on the bastion:
/*
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1"
    }
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module "kubernetes_dependencies" {
  source = "../../modules/kubernetes-dependencies"

  cluster_name             = module.eks.cluster_name
  region                   = "eu-central-1"
  amazon_container_id      = "602401143452"
  oidc_provider_arn        = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url  = module.eks.cluster_oidc_issuer_url

  enable_calico = true

  enable_aws_load_balancer_controller = true
  nlb_controller_namespace            = "kube-system"
  nlb_controller_service_account      = "aws-load-balancer-controller"

  enable_efs_csi_addon    = true
  efs_csi_namespace       = "kube-system"
  efs_csi_service_account = "efs-csi-controller-sa"

  create_efs_storage_class         = true
  efs_storage_class_name           = "efs-sc"
  efs_storage_class_reclaim_policy = "Retain"
  efs_file_system_id               = module.eks.efs_file_system_id

  create_ebs_storage_class                 = true
  ebs_storage_class_name                   = "gp3"
  ebs_storage_class_is_default             = true
  ebs_storage_class_reclaim_policy         = "Delete"
  ebs_storage_class_volume_binding_mode    = "WaitForFirstConsumer"
  ebs_storage_class_allow_volume_expansion = true
  ebs_volume_type                          = "gp3"

  tags = local.tags

  depends_on = [module.eks]
}
*/
