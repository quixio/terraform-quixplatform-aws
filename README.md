# Terraform AWS Modules for Quix Platform

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)

A collection of production-ready Terraform modules for deploying and managing infrastructure on Amazon Web Services (AWS), optimized for running the Quix Platform and related workloads.

## Overview

This repository provides modular, composable infrastructure-as-code components that enable teams to provision secure, scalable AWS infrastructure following industry best practices. Each module is designed to be used independently or combined to build complete infrastructure stacks.

## Available Modules

### Core Infrastructure

#### quix-eks
Creates and manages Amazon EKS (Elastic Kubernetes Service) clusters with comprehensive networking, storage, and security features.

**Key capabilities:**
- Production-ready Kubernetes clusters with configurable versions
- Flexible networking (create new VPC or bring your own)
- Multiple managed node groups with custom configurations
- Integrated storage solutions (EBS and EFS)
- IRSA (IAM Roles for Service Accounts) for granular permissions
- Optional Route53 DNS management
- VPC endpoint support for cost optimization

[View module documentation](modules/quix-eks/)

#### quix-eks-dependencies
Deploys essential Kubernetes controllers, operators, and add-ons required for production workloads.

**Key capabilities:**
- Network policy enforcement with Calico
- AWS Load Balancer Controller for ingress management
- EFS CSI Driver for shared storage
- Pre-configured storage classes for common use cases
- Helm chart management

[View module documentation](modules/quix-eks-dependencies/)

## Getting Started

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- kubectl (for cluster access)
- Helm >= 3.1 (for Kubernetes add-ons)

### Basic Example

```hcl
module "eks" {
  source = "./modules/quix-eks"

  cluster_name    = "production-cluster"
  cluster_version = "1.34"
  region          = "us-east-1"

  # Network configuration
  vpc_cidr        = "10.240.0.0/16"
  azs             = 2
  private_subnets = ["10.240.0.0/24", "10.240.1.0/24"]
  public_subnets  = ["10.240.100.0/24", "10.240.101.0/24"]

  # Node configuration
  node_pools = {
    default = {
      name          = "default"
      node_count    = 3
      instance_size = "m6i.large"
      disk_size     = 100
      labels        = {}
      taints        = []
    }
  }

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "production"
    Project     = "infrastructure"
  }
}

module "quix_eks_dependencies" {
  source = "./modules/quix-eks-dependencies"

  cluster_name            = module.eks.cluster_name
  region                  = "us-east-1"
  oidc_provider_arn       = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url

  enable_calico                       = true
  enable_aws_load_balancer_controller = true
  enable_efs_csi_addon                = true

  create_efs_storage_class = true
  efs_file_system_id       = module.eks.efs_file_system_id

  create_ebs_storage_class     = true
  ebs_storage_class_is_default = true

  tags = {
    Environment = "production"
    Project     = "infrastructure"
  }

  depends_on = [module.eks]
}
```

## Architecture

The modules deploy infrastructure following AWS Well-Architected Framework principles:

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Region                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    VPC                                 │  │
│  │                                                        │  │
│  │  ┌──────────────────┐      ┌──────────────────┐     │  │
│  │  │  Public Subnet   │      │  Public Subnet   │     │  │
│  │  │  AZ-A            │      │  AZ-B            │     │  │
│  │  │  - NAT Gateway   │      │                  │     │  │
│  │  │  - Load Balancers│      │                  │     │  │
│  │  └────────┬─────────┘      └──────────────────┘     │  │
│  │           │                                          │  │
│  │  ┌────────▼─────────┐      ┌──────────────────┐     │  │
│  │  │ Private Subnet   │      │ Private Subnet   │     │  │
│  │  │ AZ-A             │      │ AZ-B             │     │  │
│  │  │ - EKS Nodes      │      │ - EKS Nodes      │     │  │
│  │  │ - EFS Targets    │      │ - EFS Targets    │     │  │
│  │  └──────────────────┘      └──────────────────┘     │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │        EKS Control Plane (Managed)           │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Usage Patterns

### Bring Your Own VPC

For organizations with existing network infrastructure:

```hcl
data "aws_vpc" "existing" {
  id = "vpc-0123456789abcdef"
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

module "eks" {
  source = "./modules/quix-eks"

  cluster_name = "production-cluster"
  region       = "us-east-1"

  create_vpc         = false
  vpc_id             = data.aws_vpc.existing.id
  private_subnet_ids = data.aws_subnets.private.ids
  public_subnet_ids  = data.aws_subnets.public.ids

  # Additional configuration...
}
```

### Multiple Node Pools

Configure heterogeneous node groups for different workload types:

```hcl
node_pools = {
  general = {
    name          = "general"
    node_count    = 3
    instance_size = "m6i.large"
    disk_size     = 100
    labels        = { workload-type = "general" }
    taints        = []
  }

  compute_optimized = {
    name          = "compute"
    node_count    = 2
    instance_size = "c6i.xlarge"
    disk_size     = 100
    labels        = { workload-type = "compute-intensive" }
    taints = [{
      key    = "dedicated"
      value  = "compute"
      effect = "NO_SCHEDULE"
    }]
  }

  memory_optimized = {
    name          = "memory"
    node_count    = 2
    instance_size = "r6i.xlarge"
    disk_size     = 200
    labels        = { workload-type = "memory-intensive" }
    taints = [{
      key    = "dedicated"
      value  = "memory"
      effect = "NO_SCHEDULE"
    }]
  }
}
```

## Examples

Complete working examples are available in the `examples/` directory:

- **public-cluster** - Standard EKS cluster with public API endpoint
- **private-with-bastion** - Private cluster with bastion host for secure management
- **public-cluster-byo-vpc** - Integration with existing VPC infrastructure

Each example includes detailed documentation and can be deployed directly for testing or used as templates for production deployments.

## Configuration Options

### Network Configuration

The modules support two primary networking modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| **Managed VPC** | Module creates VPC with subnets, NAT gateway, and routing | New deployments, isolated environments |
| **Existing VPC** | Integrate with pre-existing network infrastructure | Shared environments, corporate networks |

### Storage Configuration

- **EBS (Elastic Block Store)**: High-performance block storage with gp3 volumes
- **EFS (Elastic File System)**: Shared file storage supporting ReadWriteMany access patterns

### Security Features

- IAM Roles for Service Accounts (IRSA) for fine-grained permissions
- Private API endpoint support for enhanced security
- Network policy enforcement via Calico
- Encryption at rest for storage resources
- VPC endpoints to minimize exposure to public internet

## Network Requirements

When using existing VPC infrastructure, ensure the following:

- DNS support and DNS hostnames enabled on the VPC
- Private subnets with NAT Gateway routes for internet access
- Public subnets with Internet Gateway routes
- Proper subnet tagging for EKS load balancer integration:
  - Private subnets: `kubernetes.io/role/internal-elb = 1`
  - Public subnets: `kubernetes.io/role/elb = 1`

See [BYO_VPC_GUIDE.md](BYO_VPC_GUIDE.md) for comprehensive requirements and configuration details.

## Cost Considerations

Infrastructure costs vary based on configuration. A typical production setup includes:

| Resource | Specification | Approximate Monthly Cost |
|----------|--------------|-------------------------|
| EKS Control Plane | Managed service | $73 |
| EC2 Instances | 3x m6i.large | $210 |
| NAT Gateway | Single AZ | $32 + data transfer |
| EFS Storage | 100 GB | $30 |
| Data Transfer | Variable | Varies |

Actual costs depend on usage patterns, data transfer volumes, and selected instance types.

### Cost Optimization

- Use single NAT Gateway instead of multi-AZ for non-production environments
- Implement VPC endpoints (S3, ECR) to reduce data transfer costs
- Right-size instance types based on workload requirements
- Use spot instances for fault-tolerant workloads
- Disable NAT Gateway in fully private configurations with VPC endpoints

## Upgrades and Maintenance

### Kubernetes Version Updates

1. Update the `cluster_version` variable in your configuration
2. Review the Terraform plan for changes
3. Apply the upgrade (may require node group recreation)
4. Test workloads after upgrade completion

### Module Version Updates

Review the CHANGELOG for breaking changes before upgrading module versions. Follow semantic versioning principles when updating.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |
| kubernetes | >= 2.29 |
| helm | >= 3.1 |

## Documentation

- [BYO VPC Guide](BYO_VPC_GUIDE.md) - Comprehensive guide for existing VPC integration
- [Module Documentation](modules/) - Detailed documentation for each module
- [Examples](examples/) - Working examples for common scenarios

## Troubleshooting

Common issues and solutions:

**Nodes fail to join cluster**
- Verify NAT Gateway configuration and routes
- Check security group rules permit required traffic
- Ensure subnets have appropriate tags

**Load balancer creation fails**
- Verify AWS Load Balancer Controller deployment
- Check subnet tags for Kubernetes integration
- Review IAM permissions for the controller service account

**Storage mount failures**
- Verify CSI driver installation
- Check security groups allow NFS traffic (port 2049 for EFS)
- Ensure mount targets exist in correct availability zones

Refer to individual module documentation for specific troubleshooting guidance.

## Contributing

Contributions are welcome. Please follow these guidelines:

1. Fork the repository
2. Create a feature branch with a descriptive name
3. Make changes following existing code style and conventions
4. Test changes thoroughly
5. Submit a pull request with detailed description

## Support

For issues, questions, or feature requests:

- GitHub Issues: [Report an issue](https://github.com/quixio/terraform-modules/issues)
- Documentation: Review module-specific documentation
- Community: [Quix Community Forum](https://quix.io/community)

## License

This project is licensed under the Apache 2.0 License. See LICENSE file for details.

## Acknowledgments

This project utilizes the following open source modules:

- [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)

---

Maintained by [Quix](https://quix.io)

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->