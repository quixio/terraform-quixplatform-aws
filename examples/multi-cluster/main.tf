# Multi-Cluster EKS Example
# =========================
#
# This example deploys two EKS clusters in an existing VPC:
# - Control cluster: For platform control plane components
# - Deployments cluster: For user workloads
#
# Prerequisites:
# - Existing VPC with NAT Gateway and Internet Gateway
# - Route tables for private (with NAT) and public (with IGW) subnets

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
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
}

provider "aws" {
  region = local.region
}

locals {
  region = "eu-central-1"  # Update to your region
}

# -----------------------------------------------------------------------------
# Provider auth note
# -----------------------------------------------------------------------------
# We use the exec plugin (not aws_eks_cluster_auth) so the token is fetched
# fresh at apply time. The data source token expires after ~15 min, which is
# shorter than a full cluster + node groups + addons creation, causing
# "Unauthorized" errors in the dependencies module on the first apply.

# -----------------------------------------------------------------------------
# Control Cluster
# -----------------------------------------------------------------------------

module "control" {
  source = "../../modules/quix-eks"

  cluster_name    = var.control_cluster_name
  cluster_version = "1.34"
  region          = local.region

  # Use existing VPC with our new subnets
  create_vpc         = false
  vpc_id             = var.vpc_id
  private_subnet_ids = [for s in aws_subnet.control_private : s.id]
  public_subnet_ids  = [for s in aws_subnet.control_public : s.id]

  # S3 endpoint likely already exists in VPC
  create_s3_endpoint = false

  # Cluster access
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  node_pools = {
    platform = {
      name          = "platform"
      node_count    = 3
      instance_size = "r6i.xlarge"
      disk_size     = 100
      labels        = { "quix.io/node-purpose" = "platform-services" }
    }
  }

  tags = {
    Environment = "production"
    Cluster     = var.control_cluster_name
    Role        = "control-plane"
  }
}

provider "kubernetes" {
  alias                  = "control"
  host                   = module.control.cluster_endpoint
  cluster_ca_certificate = base64decode(module.control.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.control.cluster_name, "--region", local.region]
  }
}

provider "helm" {
  alias = "control"
  kubernetes = {
    host                   = module.control.cluster_endpoint
    cluster_ca_certificate = base64decode(module.control.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.control.cluster_name, "--region", local.region]
    }
  }
}

module "control_deps" {
  source = "../../modules/quix-eks-dependencies"

  providers = {
    kubernetes = kubernetes.control
    helm       = helm.control
  }

  cluster_name            = module.control.cluster_name
  region                  = local.region
  oidc_provider_arn       = module.control.oidc_provider_arn
  cluster_oidc_issuer_url = module.control.cluster_oidc_issuer_url
  efs_file_system_id      = module.control.efs_file_system_id

  create_efs_storage_class = true
  create_ebs_storage_class = true

  depends_on = [module.control]
}

# -----------------------------------------------------------------------------
# Deployments Cluster
# -----------------------------------------------------------------------------

module "deployments" {
  source = "../../modules/quix-eks"

  cluster_name    = var.deployments_cluster_name
  cluster_version = "1.34"
  region          = local.region

  # Use existing VPC with our new subnets
  create_vpc         = false
  vpc_id             = var.vpc_id
  private_subnet_ids = [for s in aws_subnet.deployments_private : s.id]
  public_subnet_ids  = [for s in aws_subnet.deployments_public : s.id]

  # S3 endpoint likely already exists in VPC
  create_s3_endpoint = false

  # Cluster access
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  node_pools = {
    deployments = {
      name          = "deployments"
      node_count    = 3
      instance_size = "r6i.xlarge"
      disk_size     = 100
      labels        = { "quix.io/node-purpose" = "customer-deployments" }
    }
  }

  tags = {
    Environment = "production"
    Cluster     = var.deployments_cluster_name
    Role        = "data-plane"
  }
}

provider "kubernetes" {
  alias                  = "deployments"
  host                   = module.deployments.cluster_endpoint
  cluster_ca_certificate = base64decode(module.deployments.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.deployments.cluster_name, "--region", local.region]
  }
}

provider "helm" {
  alias = "deployments"
  kubernetes = {
    host                   = module.deployments.cluster_endpoint
    cluster_ca_certificate = base64decode(module.deployments.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.deployments.cluster_name, "--region", local.region]
    }
  }
}

module "deployments_deps" {
  source = "../../modules/quix-eks-dependencies"

  providers = {
    kubernetes = kubernetes.deployments
    helm       = helm.deployments
  }

  cluster_name            = module.deployments.cluster_name
  region                  = local.region
  oidc_provider_arn       = module.deployments.oidc_provider_arn
  cluster_oidc_issuer_url = module.deployments.cluster_oidc_issuer_url
  efs_file_system_id      = module.deployments.efs_file_system_id

  create_efs_storage_class = true
  create_ebs_storage_class = true

  depends_on = [module.deployments]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "control" {
  description = "Control cluster details"
  value = {
    cluster_name     = module.control.cluster_name
    cluster_endpoint = module.control.cluster_endpoint
    efs_id           = module.control.efs_file_system_id
  }
}

output "deployments" {
  description = "Deployments cluster details"
  value = {
    cluster_name     = module.deployments.cluster_name
    cluster_endpoint = module.deployments.cluster_endpoint
    efs_id           = module.deployments.efs_file_system_id
  }
}

output "kubeconfig_commands" {
  description = "Commands to configure kubectl"
  value = {
    control     = "aws eks update-kubeconfig --name ${var.control_cluster_name} --region ${local.region}"
    deployments = "aws eks update-kubeconfig --name ${var.deployments_cluster_name} --region ${local.region}"
  }
}
