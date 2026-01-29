terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1"
    }
  }
  required_version = ">= 1.5.0"
}

locals {
  tags = {
    environment = "demo"
    project     = "Quix"
  }
}

provider "aws" {
  region = "eu-central-1"
}

################################################################################
# Kubernetes and Helm Providers for EKS
################################################################################

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

module "eks" {
  source = "../../modules/quix-eks"

  # Naming and region
  cluster_name = "quix-eks-public"
  region       = "eu-central-1"

  # Networking
  vpc_cidr = "10.240.0.0/16"
  azs      = 2
  # singleaz        = "eu-central-1a"
  private_subnets = ["10.240.0.0/24", "10.240.1.0/24"]
  public_subnets  = ["10.240.100.0/24", "10.240.101.0/24"]

  # Cluster settings
  cluster_version = "1.34"

  # API endpoint and admin permissions
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # Optional features (disabled by default for public example)
  create_route53_zone      = false
  create_cert_manager_role = false

  # EBS CSI (IRSA)
  attach_kms_permissions_to_ebs_role = true

  # Dynamic node pools
  node_pools = {
    platform = {
      name          = "platform"
      node_count    = 3
      instance_size = "r6i.xlarge"
      disk_size     = 100
      labels        = { "quix.io/node-purpose" = "platform-services" }
    }
    deployments = {
      name          = "deployments"
      node_count    = 3
      instance_size = "r6i.xlarge"
      disk_size     = 100
      labels        = { "quix.io/node-purpose" = "customer-deployments" }
    }
  }

  # Fetch credentials locally
  enable_credentials_fetch = true

  # Tags
  tags = local.tags

}

module "quix_eks_dependencies" {
  source = "../../modules/quix-eks-dependencies"

  cluster_name            = module.eks.cluster_name
  region                  = "eu-central-1"
  amazon_container_id     = "602401143452"
  oidc_provider_arn       = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url

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
