# Multi-Cluster EKS with Shared VPC

This example deploys two EKS clusters (control plane and data plane) that share an existing VPC and NAT gateway. This architecture is ideal for separating platform services from customer workloads while maintaining cost efficiency and simplified networking.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Existing VPC                                    │
│                                                                              │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐        │
│  │   Control Cluster Subnets   │    │  Deployments Cluster Subnets │        │
│  │                             │    │                              │        │
│  │  Private:                   │    │  Private:                    │        │
│  │   - AZ-a: 10.0.32.0/22     │    │   - AZ-a: 10.0.40.0/22      │        │
│  │   - AZ-b: 10.0.36.0/22     │    │   - AZ-b: 10.0.44.0/22      │        │
│  │  Public:                    │    │  Public:                     │        │
│  │   - AZ-a: 10.0.48.0/24     │    │   - AZ-a: 10.0.50.0/24      │        │
│  │   - AZ-b: 10.0.49.0/24     │    │   - AZ-b: 10.0.51.0/24      │        │
│  │                             │    │                              │        │
│  │  ┌───────────────────────┐  │    │  ┌───────────────────────┐  │        │
│  │  │   EKS Control Plane   │  │    │  │   EKS Data Plane      │  │        │
│  │  │                       │  │    │  │                       │  │        │
│  │  │  ┌─────────────────┐  │  │    │  │  ┌─────────────────┐  │  │        │
│  │  │  │ Platform Pool   │  │  │    │  │  │ Deploy Pool     │  │  │        │
│  │  │  │ 3x r6i.xlarge   │  │  │    │  │  │ 3x r6i.xlarge   │  │  │        │
│  │  │  └─────────────────┘  │  │    │  │  └─────────────────┘  │  │        │
│  │  └───────────────────────┘  │    │  └───────────────────────┘  │        │
│  └─────────────────────────────┘    └──────────────────────────────┘        │
│                                                                              │
│                    ┌────────────────────────────┐                           │
│                    │   Shared NAT Gateway       │                           │
│                    │   (existing in VPC)        │                           │
│                    └────────────────────────────┘                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

This example requires an existing VPC with:
- NAT Gateway and Internet Gateway already configured
- Route tables for private (with NAT) and public (with IGW) subnets

## Network Design

### Subnet Layout

| Cluster | Subnet Type | AZ | CIDR |
|---------|-------------|-----|------|
| Control | Private | a | 10.0.32.0/22 (1024 IPs) |
| Control | Private | b | 10.0.36.0/22 (1024 IPs) |
| Control | Public | a | 10.0.48.0/24 (256 IPs) |
| Control | Public | b | 10.0.49.0/24 (256 IPs) |
| Deployments | Private | a | 10.0.40.0/22 (1024 IPs) |
| Deployments | Private | b | 10.0.44.0/22 (1024 IPs) |
| Deployments | Public | a | 10.0.50.0/24 (256 IPs) |
| Deployments | Public | b | 10.0.51.0/24 (256 IPs) |

## Usage

### Configure Variables

Create a `terraform.tfvars` file:

```hcl
vpc_id                   = "vpc-xxxxxxxxx"
private_route_table_id   = "rtb-xxxxxxxxx"  # Route table with NAT Gateway
public_route_table_id    = "rtb-xxxxxxxxx"  # Route table with IGW
control_cluster_name     = "quix-control"
deployments_cluster_name = "quix-deployments"
```

### Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Access the Clusters

```bash
# Control cluster
aws eks update-kubeconfig --name quix-control --region eu-central-1

# Deployments cluster
aws eks update-kubeconfig --name quix-deployments --region eu-central-1
```

## Node Labels

The clusters use Quix-standard node labels for workload scheduling:

| Cluster | Node Pool | Label |
|---------|-----------|-------|
| Control | platform | `quix.io/node-purpose=platform-services` |
| Deployments | deployments | `quix.io/node-purpose=customer-deployments` |

## Node Pool Configuration

EKS control plane is fully managed by AWS. System components (CoreDNS, kube-proxy) run as managed add-ons on worker nodes.

| Cluster | Pool | Count | Instance | Disk |
|---------|------|-------|----------|------|
| Control | platform | 3 | r6i.xlarge | 100GB |
| Deployments | deployments | 3 | r6i.xlarge | 100GB |

## Outputs

| Output | Description |
|--------|-------------|
| `control.cluster_name` | Control cluster name |
| `control.cluster_endpoint` | Control cluster API endpoint |
| `control.efs_id` | Control cluster EFS filesystem ID |
| `deployments.cluster_name` | Deployments cluster name |
| `deployments.cluster_endpoint` | Deployments cluster API endpoint |
| `deployments.efs_id` | Deployments cluster EFS filesystem ID |
| `kubeconfig_commands` | Commands to configure kubectl |

## Cost Optimization

This architecture optimizes costs by:
- Sharing a single VPC and NAT Gateway between clusters
- Using memory-optimized instances (r6i.xlarge) for workload pools
- EKS managed control plane (no separate master nodes to manage)

## Customization

To adjust the subnet CIDRs, edit `subnets.tf` and modify the `locals` block:

```hcl
locals {
  control_private_subnets = {
    "eu-central-1a" = "10.0.32.0/22"
    "eu-central-1b" = "10.0.36.0/22"
  }
  # ... etc
}
```
