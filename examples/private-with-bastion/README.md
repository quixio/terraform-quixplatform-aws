# Private EKS Cluster with Bastion for Dependencies Installation

This example demonstrates how to create a private EKS cluster and automatically install Kubernetes dependencies using a temporary bastion host.

## Architecture

- **EKS Cluster**: Private API endpoint (no public access)
- **Bastion Host**: Temporary EC2 instance used only for initial Kubernetes dependencies installation
- **Dependencies**: Automatically installed via the bastion (Calico, AWS Load Balancer Controller, EFS CSI, storage classes)

## Requirements

- **NAT Gateway**: Required in the VPC for the bastion to access AWS services (SSM, ECR, etc.)
- **AWS CLI**: Local AWS CLI with appropriate credentials for EKS and SSM
- **Terraform**: >= 1.5.0
- **IAM Permissions**: Ability to create EKS clusters, EC2 instances, IAM roles, and SSM access

## Usage

### First Deployment (with dependencies installation)

1. Deploy the cluster with the bastion to install Kubernetes dependencies:

```bash
terraform apply
```

By default, resources are created in `eu-central-1` region and `deploy_k8s_dependencies = true`. To use a different region:

```bash
terraform apply -var="region=us-east-1"
```

Or create a `terraform.tfvars` file:

```hcl
region = "us-east-1"
```

This will:
- Create the EKS cluster in your specified region
- Create a bastion host in a private subnet
- Automatically install Kubernetes dependencies via SSM
- The bastion remains running after deployment

### After Dependencies are Installed

2. **Remove the bastion to save costs** by setting the variable to `false`:

Create a `terraform.tfvars` file:

```hcl
deploy_k8s_dependencies = false
```

Or pass it via command line:

```bash
terraform apply -var="deploy_k8s_dependencies=false"
```

This will:
- **Keep** the EKS cluster and all Kubernetes resources
- **Delete** the bastion EC2 instance
- **Delete** all bastion-related IAM roles and policies
- Save EC2 costs (~$15-20/month for t3.small)

## Variable Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `region` | string | `"eu-central-1"` | AWS region where resources will be created. |
| `deploy_k8s_dependencies` | bool | `true` | Deploy Kubernetes dependencies via bastion. Set to `false` after first successful deployment to remove bastion and save costs. |

## How It Works

### Bastion Host Setup

The bastion host (Ubuntu 22.04) is automatically configured with:
- **AWS Systems Manager Agent** (SSM Agent) for remote access
- **Terraform** (from HashiCorp apt repository)
- **kubectl** (Kubernetes CLI)
- **helm** (Kubernetes package manager)
- **AWS CLI v2** (for EKS and IAM operations)

All tools are installed via user_data during instance launch, with a marker file created when setup is complete.

### Deployment Process

The automated deployment follows these steps:

1. **Wait for bastion readiness**: Polls for SSM Agent to be online and marker file to exist
2. **Generate Terraform config**: Creates a configuration file using the `k8s-dependencies.tftpl` template
3. **Upload to bastion**: Transfers the config via base64 encoding through SSM Send Command
4. **Configure kubectl**: Sets up cluster access using IAM role authentication
5. **Execute Terraform**: Runs `terraform init`, `plan`, and `apply` to install all dependencies
6. **Verify deployment**: Returns outputs and logs for verification

The entire process takes approximately 10-15 minutes on first run.

## Workflow

```
First Run (deploy_k8s_dependencies = true):
├── Create EKS cluster (private)
├── Create bastion host (Ubuntu 22.04 in private subnet)
│   ├── Install SSM Agent via snap
│   ├── Install Terraform, kubectl, helm, AWS CLI
│   └── Wait for setup completion
├── Deploy Terraform configuration via SSM:
│   ├── Upload k8s-dependencies config
│   ├── Configure kubectl access
│   └── Apply Terraform to install dependencies
├── Installed dependencies:
│   ├── Calico network policy
│   ├── AWS Load Balancer Controller (with IRSA)
│   ├── EFS CSI driver (with IRSA)
│   ├── EBS storage class (gp3, default)
│   └── EFS storage class
└── Bastion remains running

Subsequent Runs (deploy_k8s_dependencies = false):
├── EKS cluster: ✓ (unchanged)
├── Kubernetes dependencies: ✓ (already installed)
└── Bastion: ✗ (destroyed to save costs)
```

## Cost Optimization

**Before** (with bastion):
- EKS cluster: ~$73/month
- 2x m6i.large nodes: ~$140/month
- t3.small bastion: ~$15/month
- **Total: ~$228/month**

**After** (bastion removed):
- EKS cluster: ~$73/month
- 2x m6i.large nodes: ~$140/month
- **Total: ~$213/month** (saves ~$15/month)

## Accessing the Private Cluster

Since the cluster API is private, you need to access it from within the VPC:

### Option 1: Temporarily enable bastion
Set `deploy_k8s_dependencies = true` and apply. Then connect:

```bash
# Get the SSM command from outputs
terraform output connect_to_bastion

# Connect to bastion (use your configured region)
aws ssm start-session --target <instance-id> --region <your-region>

# Configure kubectl on bastion
aws eks update-kubeconfig --name quix-eks-private --region <your-region>
kubectl get nodes
```

### Option 2: VPN or Direct Connect
Set up AWS Client VPN or Direct Connect to access the VPC from your local machine.

### Option 3: Cloud9 or EC2 Jump Host
Create a Cloud9 environment or EC2 instance in the same VPC for cluster management.

## Troubleshooting

### SSM Agent not connecting

If the bastion fails to connect via SSM:

1. **Check SSM Agent status** - The bastion automatically installs SSM Agent via snap during user_data
2. **Verify NAT Gateway** - Private subnet must have NAT Gateway for SSM endpoints
3. **Check user_data logs**:
```bash
# Terraform will automatically check these during deployment
# Manual check if needed (replace <your-region> with your configured region):
aws ssm send-command \
  --instance-ids <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["tail -100 /var/log/cloud-init-output.log"]' \
  --region <your-region>
```

The deployment script waits up to 10 minutes for the marker file (`/tmp/in-bastion-marker`) to appear, indicating setup is complete.

### Dependencies failed to install

1. Check the SSM command output:
```bash
terraform apply
# Look for errors in the deployment logs
```

2. Manually access the bastion to debug:
```bash
# Use the region you configured
aws ssm start-session --target <instance-id> --region <your-region>
cd /opt/terraform/k8s-dependencies
terraform plan
```

3. Verify kubectl connectivity:
```bash
aws ssm start-session --target <instance-id> --region <your-region>

# Inside bastion:
aws eks update-kubeconfig --name quix-eks-private --region <your-region>
kubectl get nodes
```

### Need to reinstall dependencies

Set the variable back to `true` and apply:
```bash
terraform apply -var="deploy_k8s_dependencies=true"
```

The script will skip resources that already exist (idempotent).

## Security Notes

- The bastion is in a **private subnet** (no public IP)
- Access is via **SSM Session Manager** only (no SSH keys required)
- Bastion uses the same security group as EKS nodes (already has cluster access)
- After dependencies are installed, remove the bastion for a smaller attack surface
