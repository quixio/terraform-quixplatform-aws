terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      version               = ">= 2.29"
      configuration_aliases = []
    }
    helm = {
      source                = "hashicorp/helm"
      version               = ">= 3.1"
      configuration_aliases = []
    }
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0"
      configuration_aliases = []
    }
  }
}
