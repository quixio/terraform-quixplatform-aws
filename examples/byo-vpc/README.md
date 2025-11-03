# Bring Your Own VPC (BYO VPC) Example

This example demonstrates how to deploy an EKS cluster using an existing VPC, subnets, and network infrastructure.

## Overview

Instead of creating a new VPC, this configuration uses existing VPC resources:
- Existing VPC
- Existing private subnets (for EKS nodes)
- Existing public subnets (for load balancers)
- Existing NAT Gateway (assumed to be configured in the VPC)
- Optional: Existing S3 VPC Endpoint

## Prerequisites

Before using this example, ensure your existing VPC has:

1. **Private Subnets**: For EKS worker nodes
   - Must have internet access via NAT Gateway
   - Should be tagged appropriately for EKS internal load balancers:
     ```
     kubernetes.io/role/internal-elb = 1
     ```

2. **Public Subnets**: For public load balancers
   - Must have internet gateway route
   - Should be tagged appropriately for EKS load balancers:
     ```
     kubernetes.io/role/elb = 1
     ```

3. **NAT Gateway**: For outbound internet access from private subnets

4. **VPC Endpoints** (Optional but recommended):
   - S3 Gateway Endpoint (can be created by module if not exists)
   - ECR API and DKR endpoints (recommended for better performance)

## Configuration

### Step 1: Update VPC and Subnet IDs

Edit [`main.tf`](main.tf) and replace the placeholder values with your actual VPC and subnet information:

```hcl
# Option 1: Use VPC ID directly
data "aws_vpc" "existing" {
  id = "vpc-xxxxxxxxxxxxxxxxx" # Replace with your VPC ID
}

# Or Option 2: Filter by tags
data "aws_vpc" "existing" {
  tags = {
    Name = "my-existing-vpc"
  }
}

# Update subnet filters to match your tagging convention
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  tags = {
    Type = "private"  # Adjust to match your tags
  }
}
```

### Step 2: Configure the EKS Module

Key configuration parameters for BYO VPC:

```hcl
module "eks" {
  source = "../../modules/quix-eks"

  # BYO VPC Configuration
  create_vpc         = false                     # Disable VPC creation
  vpc_id             = data.aws_vpc.existing.id  # Use existing VPC
  private_subnet_ids = data.aws_subnets.private.ids
  public_subnet_ids  = data.aws_subnets.public.ids

  # S3 VPC endpoint
  create_s3_endpoint = false  # Set to false if endpoint already exists

  # Note: When create_vpc = false, these variables are not required:
  # - vpc_cidr
  # - azs
  # - private_subnets
  # - public_subnets
  # - enable_nat_gateway (NAT Gateway must already exist in your VPC)

  # ... rest of configuration
}
```

## Network Requirements Checklist

- [ ] VPC has DNS support enabled
- [ ] VPC has DNS hostnames enabled
- [ ] Private subnets have routes to NAT Gateway
- [ ] Public subnets have routes to Internet Gateway
- [ ] Subnets are properly tagged for EKS
- [ ] Security groups allow necessary communication
- [ ] VPC has sufficient IP addresses available

## Subnet Tagging Requirements

EKS requires specific tags on subnets:

### Private Subnets (for internal load balancers):
```
kubernetes.io/role/internal-elb = 1
```

### Public Subnets (for external load balancers):
```
kubernetes.io/role/elb = 1
```

### Optional but Recommended:
```
kubernetes.io/cluster/<cluster-name> = shared
```

## VPC Endpoints

If your VPC doesn't have an S3 VPC endpoint, set `create_s3_endpoint = true` in the module configuration. This will create a gateway endpoint for S3, which:
- Reduces NAT Gateway costs
- Improves performance for S3 access
- Keeps S3 traffic within AWS network

For production environments, consider adding these VPC endpoints:
- `com.amazonaws.region.ecr.api`
- `com.amazonaws.region.ecr.dkr`
- `com.amazonaws.region.ec2`
- `com.amazonaws.region.sts`
- `com.amazonaws.region.logs`

## Deployment

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Get cluster credentials
aws eks update-kubeconfig --name quix-eks-byo-vpc --region eu-central-1
```

## Cleanup

```bash
terraform destroy
```

**Note**: This will only destroy the EKS cluster and related resources. Your VPC and subnets will remain intact.

## Troubleshooting

### Nodes not joining the cluster
- Verify NAT Gateway is properly configured
- Check security group rules
- Ensure subnets have proper tags

### Load balancers not creating
- Verify subnet tags for EKS load balancers
- Check that AWS Load Balancer Controller is deployed correctly
- Ensure proper IAM permissions

### DNS resolution issues
- Enable DNS support and DNS hostnames on VPC
- Verify VPC DHCP options set includes DNS servers

## Comparison: Create VPC vs BYO VPC

| Feature | Create VPC (`create_vpc = true`) | BYO VPC (`create_vpc = false`) |
|---------|----------------------------------|--------------------------------|
| VPC Management | Module creates new VPC | Use existing VPC |
| Network Control | Opinionated defaults | Full control |
| NAT Gateway | Created by module | Must exist |
| VPC Endpoints | Optional, created by module | Must exist or disable |
| Use Case | New deployments | Existing infrastructure |

## Related Examples

- [Public Cluster](../public-cluster/) - Creates a new VPC with public access
- [Private with Bastion](../private-with-bastion/) - Creates a new VPC with bastion host
