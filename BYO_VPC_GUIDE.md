# Bring Your Own VPC (BYO VPC) Guide

This document explains how to use the `quix-eks` module with your existing network infrastructure.

## Overview of Changes

The module now supports two modes of operation:

1. **Create VPC Mode** (`create_vpc = true`, default): The module creates all network infrastructure
2. **BYO VPC Mode** (`create_vpc = false`): The module uses your existing VPC, subnets, and NAT Gateway

## New Variables

### BYO VPC Variables

```hcl
# Main control
variable "create_vpc" {
  description = "If false, use an existing VPC"
  type        = bool
  default     = true
}

# Existing resource IDs (required when create_vpc = false)
variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs"
  type        = list(string)
  default     = []
}

# NAT Gateway configuration
variable "enable_nat_gateway" {
  description = "Whether to create a single NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# VPC endpoints
variable "create_s3_endpoint" {
  description = "If false, assumes S3 endpoint already exists"
  type        = bool
  default     = true
}
```

### VPC Creation Variables (modified)

When `create_vpc = true`, these variables are **required**:

```hcl
variable "vpc_cidr" {
  description = "VPC CIDR (required when create_vpc = true)"
  type        = string
  default     = null  # Now optional with default null
}

variable "azs" {
  description = "Number of availability zones (required when create_vpc = true)"
  type        = number
  default     = null  # Now optional with default null
}

variable "private_subnets" {
  description = "Private subnet CIDRs (required when create_vpc = true)"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "Public subnet CIDRs (required when create_vpc = true)"
  type        = list(string)
  default     = []
}
```

## Usage

### Option 1: Create New VPC (default behavior)

```hcl
module "eks" {
  source = "../../modules/quix-eks"

  cluster_name = "my-cluster"
  region       = "eu-central-1"

  # Create new VPC (create_vpc = true by default)
  vpc_cidr        = "10.240.0.0/16"
  azs             = 2
  private_subnets = ["10.240.0.0/24", "10.240.1.0/24"]
  public_subnets  = ["10.240.100.0/24", "10.240.101.0/24"]

  # ... rest of configuration
}
```

### Option 2: Use Existing VPC

```hcl
# Get existing VPC
data "aws_vpc" "existing" {
  id = "vpc-0123456789abcdef0"
}

# Get existing subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  tags = {
    Type = "private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  tags = {
    Type = "public"
  }
}

module "eks" {
  source = "../../modules/quix-eks"

  cluster_name = "my-cluster"
  region       = "eu-central-1"

  # Use existing VPC
  create_vpc         = false
  vpc_id             = data.aws_vpc.existing.id
  private_subnet_ids = data.aws_subnets.private.ids
  public_subnet_ids  = data.aws_subnets.public.ids

  # If your VPC already has an S3 endpoint
  create_s3_endpoint = false

  # NOTE: You don't need to specify:
  # - vpc_cidr
  # - azs
  # - private_subnets
  # - public_subnets

  # ... rest of configuration
}
```

## Existing VPC Requirements

To use an existing VPC, it must meet the following requirements:

### 1. DNS Configuration
```bash
# The VPC must have these options enabled:
- enableDnsSupport = true
- enableDnsHostnames = true
```

### 2. Private Subnets

Private subnets must:
- Have internet access via NAT Gateway
- Be tagged for EKS:
  ```
  kubernetes.io/role/internal-elb = 1
  ```

### 3. Public Subnets

Public subnets must:
- Have a route to Internet Gateway
- Be tagged for EKS:
  ```
  kubernetes.io/role/elb = 1
  ```

### 4. NAT Gateway

- Must exist in a public subnet
- Must be configured in the route table of private subnets

### 5. VPC Endpoints (Recommended)

If your VPC doesn't have an S3 endpoint, the module can create it by setting:
```hcl
create_s3_endpoint = true
```

For production, consider adding these endpoints manually:
- `com.amazonaws.{region}.ecr.api`
- `com.amazonaws.{region}.ecr.dkr`
- `com.amazonaws.{region}.ec2`
- `com.amazonaws.{region}.sts`
- `com.amazonaws.{region}.logs`

## Migrating Existing Configuration

If you already have a cluster with a VPC created by the module and want to migrate to BYO VPC:

### ⚠️ WARNING
This migration requires **recreating the cluster**. Zero-downtime migration is not possible.

### Steps:

1. **Export current VPC information**
   ```bash
   terraform output vpc_id
   terraform output private_subnets
   terraform output public_subnets
   ```

2. **Import VPC to new state** (if you want to keep it)
   ```bash
   # Remove VPC from module
   terraform state rm module.eks.module.vpc

   # Import it as an independent resource
   # (You'll need to create separate configuration for the VPC)
   ```

3. **Update module configuration**
   ```hcl
   module "eks" {
     # ...
     create_vpc         = false
     vpc_id             = "vpc-xxx"  # From step 1
     private_subnet_ids = ["subnet-xxx", "subnet-yyy"]
     public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
   }
   ```

4. **Recreate cluster**
   ```bash
   terraform apply
   ```

## Complete Example

See the complete example at [`examples/byo-vpc/`](examples/byo-vpc/)

## Internal Architecture

### Modified Files

1. **`variables.tf`**: Adds BYO VPC variables
2. **`vpc.tf`**: Conditional logic to create or use existing VPC
3. **`vpc-endpoints.tf`**: Conditional support for S3 endpoint
4. **`main.tf`**: Logic to detect AZs from existing subnets
5. **`eks.tf`**: Uses locals instead of direct VPC module outputs
6. **`outputs.tf`**: Returns correct values based on mode

### Unified Locals

The module uses locals to abstract the resource source:

```hcl
locals {
  # Unifies VPC ID
  vpc_id = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id

  # Unifies subnet IDs
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
  public_subnet_ids  = var.create_vpc ? module.vpc[0].public_subnets : var.public_subnet_ids

  # Route tables for VPC endpoints
  private_route_table_ids = var.create_vpc ?
    module.vpc[0].private_route_table_ids :
    data.aws_route_tables.existing_private[0].ids
}
```

## Troubleshooting

### Error: "No private subnets found"

**Cause**: Filters in `data.aws_subnets.private` don't match your tags

**Solution**: Adjust filters to match your tagging convention:
```hcl
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  # Adjust these tags for your VPC
  tags = {
    Tier = "Private"  # or whatever tag you use
  }
}
```

### Error: "Nodes not joining cluster"

**Possible causes**:
1. NAT Gateway not configured correctly
2. Security groups blocking traffic
3. Subnets missing correct tags

**Solution**: Verify:
```bash
# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxx"

# Check NAT Gateway
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxx"

# Check subnet tags
aws ec2 describe-subnets --subnet-ids subnet-xxx
```

### Error: "Failed to create load balancer"

**Cause**: Subnets don't have the required EKS tags

**Solution**: Add tags to subnets:
```bash
# For public subnets
aws ec2 create-tags --resources subnet-xxx \
  --tags Key=kubernetes.io/role/elb,Value=1

# For private subnets
aws ec2 create-tags --resources subnet-xxx \
  --tags Key=kubernetes.io/role/internal-elb,Value=1
```

## Cost Considerations

### Create VPC Mode
- NAT Gateway: ~$32/month + data transfer
- VPC Endpoints: ~$7/month per endpoint (optional)

### BYO VPC Mode
- Costs depend on your existing infrastructure
- You can share NAT Gateway with other resources
- Potential savings if you already have infrastructure

## Frequently Asked Questions

**Q: Can I use a VPC in a different account?**
A: Not directly. You would need to configure VPC peering or Transit Gateway.

**Q: Can I mix created and existing subnets?**
A: No. You must use `create_vpc = true` (all created) or `create_vpc = false` (all existing).

**Q: Does the module modify my existing VPC?**
A: No. The module only reads information from your VPC. It can create resources within it (EKS, ENIs, etc.) but doesn't modify the VPC or subnets.

**Q: What about existing VPC endpoints?**
A: If your VPC already has an S3 endpoint, set `create_s3_endpoint = false`. The module will detect it automatically.

**Q: Can I use only some of my subnets?**
A: Yes, specify only the IDs of the subnets you want to use in `private_subnet_ids` and `public_subnet_ids`.
