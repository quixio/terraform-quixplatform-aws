# Private EKS Cluster with Bastion Example

This example demonstrates how to create an EKS cluster with a **completely private API** (`cluster_endpoint_public_access = false`) along with a bastion host to run Terraform and manage the cluster.

## Architecture

```
Internet
    |
    v
[NAT Gateway] <-- [Public Subnets]
    |
    v
[Private Subnets]
    |
    +-- [EKS Control Plane] (Private API)
    |
    +-- [EKS Worker Nodes]
    |
    +-- [Bastion EC2] (Terraform Runner)
```

## Components

1. **EKS Cluster**: Private API endpoint, only accessible from within the VPC
2. **Bastion Host**: EC2 t3.small with Terraform, kubectl and helm pre-installed
3. **IAM Roles**: Permissions for the bastion to manage the cluster
4. **Security Groups**: Rules to allow bastion access to the control plane

## Usage

### Step 1: Create the base infrastructure

```bash
cd examples/private-with-bastion

# Initialize Terraform
terraform init

# Create the EKS cluster and bastion (without kubernetes-dependencies module)
terraform apply
```

This will create:
- VPC with public and private subnets
- EKS cluster with private API
- Bastion host in private subnet with SSM enabled

### Step 2: Connect to the bastion

Once the bastion is created, connect using AWS Systems Manager Session Manager:

```bash
# Get the instance ID from output
terraform output terraform_runner_instance_id

# Connect (requires AWS CLI configured and Session Manager plugin)
aws ssm start-session --target <instance-id> --region eu-central-1
```

**Note**: You don't need SSH keys or open ports. SSM Session Manager works over HTTPS.

### Step 3: Configure kubectl on the bastion

Inside the bastion:

```bash
# Configure kubectl for the cluster
aws eks update-kubeconfig --name quix-eks-private --region eu-central-1

# Verify connectivity
kubectl get nodes
```

### Step 4: Deploy Kubernetes dependencies

There are two options:

#### Option A: From the bastion with local files

1. On the bastion, edit `k8s-config.tf` and uncomment all content
2. Run:

```bash
terraform init
terraform apply
```

#### Option B: Create a separate project on the bastion

1. Create a new directory on the bastion:

```bash
sudo -i
cd /opt/terraform
mkdir k8s-dependencies
cd k8s-dependencies
```

2. Create a `main.tf` file:

```hcl
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
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_eks_cluster" "this" {
  name = "quix-eks-private"
}

data "aws_eks_cluster_auth" "this" {
  name = "quix-eks-private"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module "kubernetes_dependencies" {
  source = "git::https://github.com/your-org/terraform-modules.git//aws/modules/kubernetes-dependencies"

  cluster_name             = "quix-eks-private"
  region                   = "eu-central-1"
  oidc_provider_arn        = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  cluster_oidc_issuer_url  = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  enable_calico                       = true
  enable_aws_load_balancer_controller = true
  enable_efs_csi_addon                = true

  # ... rest of configuration
}
```

3. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Prerequisites

1. **AWS CLI**: Installed and configured with credentials
2. **Session Manager Plugin**: To connect to bastion without SSH
   ```bash
   # macOS
   brew install --cask session-manager-plugin

   # Linux
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
   sudo dpkg -i session-manager-plugin.deb
   ```

3. **IAM Permissions**: Your user/role needs:
   - `eks:*`
   - `ec2:*`
   - `iam:*`
   - `ssm:StartSession`

## Bastion Management

### Update the bastion

If you need to update software on the bastion:

```bash
aws ssm start-session --target <instance-id>

# Once connected
sudo yum update -y

# Update Terraform
cd /tmp
wget https://releases.hashicorp.com/terraform/1.10.0/terraform_1.10.0_linux_amd64.zip
unzip terraform_1.10.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Transfer files to bastion

Use S3 as an intermediary:

```bash
# From your local machine
aws s3 cp my-terraform-code.tar.gz s3://my-bucket/

# From the bastion
aws s3 cp s3://my-bucket/my-terraform-code.tar.gz .
tar xzf my-terraform-code.tar.gz
```

### Delete bastion when not in use

To save costs (although t3.small is ~$15/month):

```bash
aws ec2 stop-instances --instance-ids <instance-id>
```

To start it again:

```bash
aws ec2 start-instances --instance-ids <instance-id>
```

## Estimated Costs

| Resource | Type | Monthly cost (approx) |
|---------|------|----------------------|
| EKS Control Plane | - | $73 |
| Worker Nodes | 2x m6i.large | ~$140 |
| Bastion | t3.small | ~$15 |
| NAT Gateway | 1x | ~$32 + data transfer |
| **Total** | | **~$260/month** |

**Note**: You can stop the bastion when not in use to save ~$15/month.

## Security

### Advantages of this setup:

1. ✅ **Private API**: The control plane is not exposed to the internet
2. ✅ **No SSH**: Bastion access via SSM (HTTPS)
3. ✅ **IAM-based**: All authentication via IAM roles
4. ✅ **Auditable**: All SSM sessions are logged to CloudWatch
5. ✅ **Compliance-ready**: Meets private bastion requirements

### Considerations:

- The bastion has broad permissions to manage the cluster
- Consider using Session Manager logging for complete auditing
- Implement MFA for bastion access in production
- Use IAM roles with least privilege in production

## Troubleshooting

### Cannot connect to bastion via SSM

1. Verify the bastion has internet access (via NAT Gateway)
2. Verify SSM agent is running:
   ```bash
   sudo systemctl status amazon-ssm-agent
   ```
3. Verify bastion IAM role includes `AmazonSSMManagedInstanceCore`

### kubectl cannot connect to cluster

1. Verify bastion security group allows HTTPS traffic to VPC CIDR
2. Verify bastion IAM role has EKS permissions
3. Verify kubectl configuration:
   ```bash
   kubectl config view
   ```

### Terraform cannot download providers

1. Verify bastion has internet access (NAT Gateway)
2. Verify connectivity:
   ```bash
   curl -I https://releases.hashicorp.com
   ```

## References

- [EKS Private Clusters](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Terraform EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
