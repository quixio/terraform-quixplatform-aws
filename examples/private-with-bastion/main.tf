terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

################################################################################
# Variables
################################################################################

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-central-1"
}

variable "deploy_k8s_dependencies" {
  description = "Deploy Kubernetes dependencies via bastion. Set to false after first successful deployment to save resources."
  type        = bool
  default     = true
}

locals {
  tags = {
    environment = "production"
    project     = "Quix"
  }
}

provider "aws" {
  region = var.region
}

################################################################################
# EKS Cluster with Private API
################################################################################

module "eks" {
  source = "../../modules/quix-eks"

  # Naming and region
  cluster_name = "quix-eks-private"
  region       = var.region

  # Networking
  vpc_cidr        = "10.240.0.0/16"
  azs             = 2
  private_subnets = ["10.240.0.0/24", "10.240.1.0/24"]
  public_subnets  = ["10.240.100.0/24", "10.240.101.0/24"]

  # Cluster settings
  cluster_version = "1.34"

  # IMPORTANT: API endpoint is PRIVATE only
  cluster_endpoint_public_access           = false
  enable_cluster_creator_admin_permissions = true

  # Optional features
  create_route53_zone      = false
  create_cert_manager_role = false

  # EBS CSI (IRSA)
  attach_kms_permissions_to_ebs_role = true

  # Single node pool for all workloads (platform services + customer deployments)
  # You can add multiple pools with quix.io/node-purpose labels if workload separation is needed
  # Valid label values: "platform-services", "customer-deployments"
  node_pools = {
    workloads = {
      name          = "workloads"
      node_count    = 4
      instance_size = "r6i.xlarge"
      disk_size     = 100
    }
  }

  # Fetch credentials locally (won't work from outside VPC)
  enable_credentials_fetch = false

  # Tags
  tags = local.tags
}

################################################################################
# Bastion Host for Terraform Execution
################################################################################

data "aws_ami" "ubuntu" {
  count       = var.deploy_k8s_dependencies ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "terraform_runner" {
  count = var.deploy_k8s_dependencies ? 1 : 0
  ami           = data.aws_ami.ubuntu[0].id
  instance_type = "t3.small"
  subnet_id     = module.eks.private_subnets[0]

  # Use the same security group as EKS nodes (already has access to control plane)
  vpc_security_group_ids = [module.eks.node_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.terraform_runner[0].name

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -x

    echo "========================================"
    echo "Starting bastion setup at $(date)"
    echo "========================================"

    # Update package list
    echo "Updating package list..."
    apt-get update -y

    # Install prerequisites
    echo "Installing prerequisites..."
    apt-get install -y curl gnupg software-properties-common git unzip

    # Install SSM Agent (required for AWS Systems Manager)
    echo "Installing SSM Agent..."
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service

    # Add HashiCorp repo and install Terraform
    echo "Adding HashiCorp GPG key..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -

    echo "Adding HashiCorp repository..."
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

    echo "Installing Terraform from HashiCorp repo..."
    apt-get update -y
    apt-get install -y terraform

    # Verify Terraform
    echo "Verifying Terraform installation..."
    terraform version
    which terraform

    # Install kubectl
    echo "Installing kubectl..."
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update -y
    apt-get install -y kubectl

    # Verify kubectl
    echo "Verifying kubectl installation..."
    kubectl version --client
    which kubectl

    # Install helm
    echo "Installing helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Verify helm
    echo "Verifying helm installation..."
    helm version
    which helm

    # Install AWS CLI v2 (Ubuntu doesn't have it by default)
    echo "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip

    # Configure AWS CLI
    echo "Configuring AWS CLI..."
    aws configure set default.region ${var.region}

    # Create directory for terraform code
    echo "Creating terraform directory..."
    mkdir -p /opt/terraform
    chown ubuntu:ubuntu /opt/terraform

    # Final verification
    echo "Final verification of all tools..."
    echo "Terraform: $(terraform version | head -1)"
    echo "Kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    echo "Helm: $(helm version --short)"
    echo "AWS CLI: $(aws --version)"

    # Create marker file ONLY if everything succeeded
    echo "Creating marker file..."
    touch /tmp/in-bastion-marker

    echo "========================================"
    echo "Bastion setup complete at $(date)"
    echo "========================================"
  EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.tags, {
    Name = "${module.eks.cluster_name}-terraform-runner"
  })
}

################################################################################
# IAM Role for Terraform Runner
################################################################################

resource "aws_iam_role" "terraform_runner" {
  count       = var.deploy_k8s_dependencies ? 1 : 0
  name        = "${module.eks.cluster_name}-terraform-runner-role"
  description = "IAM role for EC2 instance running Terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

# Permissions to access the EKS cluster
resource "aws_iam_role_policy_attachment" "terraform_runner_eks_cluster" {
  count      = var.deploy_k8s_dependencies ? 1 : 0
  role       = aws_iam_role.terraform_runner[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Permissions to describe the cluster
resource "aws_iam_role_policy_attachment" "terraform_runner_eks_describe" {
  count      = var.deploy_k8s_dependencies ? 1 : 0
  role       = aws_iam_role.terraform_runner[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# SSM to connect without SSH
resource "aws_iam_role_policy_attachment" "terraform_runner_ssm" {
  count      = var.deploy_k8s_dependencies ? 1 : 0
  role       = aws_iam_role.terraform_runner[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Additional permissions for Terraform and Kubernetes resources
resource "aws_iam_role_policy" "terraform_runner_additional" {
  count = var.deploy_k8s_dependencies ? 1 : 0
  name = "${module.eks.cluster_name}-terraform-runner-policy"
  role = aws_iam_role.terraform_runner[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EKS and IAM read permissions
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetOpenIDConnectProvider",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeAvailabilityZones",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets"
        ]
        Resource = "*"
      },
      # IAM permissions to create service account roles (for IRSA)
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/${module.eks.cluster_name}-*",
          "arn:aws:iam::*:role/quix-*-${module.eks.cluster_name}"
        ]

      },
      # Allow creating IAM policies for service accounts
      {
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:TagPolicy"
        ]
        Resource = [
          "arn:aws:iam::*:policy/${module.eks.cluster_name}-*",
          "arn:aws:iam::*:policy/quix-*-${module.eks.cluster_name}"
        ]
      },
      # Elastic Load Balancing permissions for ALB/NLB controller
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "terraform_runner" {
  count = var.deploy_k8s_dependencies ? 1 : 0
  name = "${module.eks.cluster_name}-terraform-runner-profile"
  role = aws_iam_role.terraform_runner[0].name

  tags = local.tags
}

################################################################################
# Grant Bastion Access to EKS Cluster
################################################################################

# Add the bastion's IAM role to EKS cluster access with admin policy
resource "aws_eks_access_entry" "terraform_runner" {
  count         = var.deploy_k8s_dependencies ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.terraform_runner[0].arn
  type          = "STANDARD"

  tags = local.tags

  depends_on = [module.eks]
}

# Associate cluster admin policy to the access entry
resource "aws_eks_access_policy_association" "terraform_runner_admin" {
  count         = var.deploy_k8s_dependencies ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.terraform_runner[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform_runner]
}

################################################################################
# Outputs
################################################################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "terraform_runner_instance_id" {
  description = "Instance ID of the Terraform runner bastion"
  value       = var.deploy_k8s_dependencies ? aws_instance.terraform_runner[0].id : "Bastion not deployed (deploy_k8s_dependencies=false)"
}

output "connect_to_bastion" {
  description = "Command to connect to the bastion via SSM"
  value       = var.deploy_k8s_dependencies ? "aws ssm start-session --target ${aws_instance.terraform_runner[0].id} --region ${var.region}" : "Bastion not deployed (deploy_k8s_dependencies=false)"
}

output "configure_kubectl_from_bastion" {
  description = "Command to run on bastion to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "kubernetes_dependencies_status" {
  description = "Status of Kubernetes dependencies deployment"
  value       = var.deploy_k8s_dependencies ? "Deployed automatically via bastion. Check terraform output for details." : "Skipped (deploy_k8s_dependencies=false)"
}

output "manual_access_instructions" {
  description = "Instructions for manual access to the bastion (if needed)"
  value       = var.deploy_k8s_dependencies ? "The Kubernetes dependencies are deployed automatically.\n\nIf you need manual access to the bastion for troubleshooting:\n\n1. Connect via SSM:\n   aws ssm start-session --target ${aws_instance.terraform_runner[0].id} --region ${var.region}\n\n2. Check kubectl access:\n   aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}\n   kubectl get nodes\n\n3. View Terraform state:\n   cd /opt/terraform/k8s-dependencies\n   terraform show\n\nNote: The bastion has Terraform, kubectl, and helm pre-installed." : "Bastion not deployed. Set deploy_k8s_dependencies=true to deploy Kubernetes dependencies."
}
