terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

locals {
  tags = {
    environment = "production"
    project     = "Quix"
  }
}

provider "aws" {
  region = "eu-central-1"
}

################################################################################
# EKS Cluster with Private API
################################################################################

module "eks" {
  source = "../../modules/quix-eks"

  # Naming and region
  cluster_name = "quix-eks-private"
  region       = "eu-central-1"

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

  # Dynamic node pools
  node_pools = {
    default = {
      name          = "default"
      node_count    = 2
      instance_size = "m6i.large"
      disk_size     = 75
      labels        = {}
      taints        = []
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

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "terraform_runner" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"
  subnet_id     = module.eks.private_subnets[0]

  vpc_security_group_ids = [aws_security_group.terraform_runner.id]
  iam_instance_profile   = aws_iam_instance_profile.terraform_runner.name

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    yum update -y

    # Install git
    yum install -y git unzip

    # Install Terraform
    cd /tmp
    wget https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip
    unzip terraform_1.9.0_linux_amd64.zip
    mv terraform /usr/local/bin/
    chmod +x /usr/local/bin/terraform

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Install helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Configure AWS CLI to use IMDSv2
    aws configure set default.region eu-central-1

    # Create directory for terraform code
    mkdir -p /opt/terraform
    chown ec2-user:ec2-user /opt/terraform

    # Create marker file
    touch /tmp/in-bastion-marker

    echo "Terraform runner setup complete" > /var/log/setup-complete.log
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

resource "aws_security_group" "terraform_runner" {
  name_prefix = "${module.eks.cluster_name}-terraform-runner-"
  description = "Security group for Terraform runner instance"
  vpc_id      = module.eks.vpc_id

  # Access to EKS control plane
  egress {
    description = "HTTPS to EKS control plane"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.eks.vpc_cidr]
  }

  # Internet access to download providers, charts, etc
  egress {
    description = "HTTPS to internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP for package repositories
  egress {
    description = "HTTP to internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${module.eks.cluster_name}-terraform-runner-sg"
  })
}

################################################################################
# IAM Role for Terraform Runner
################################################################################

resource "aws_iam_role" "terraform_runner" {
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
  role       = aws_iam_role.terraform_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Permissions to describe the cluster
resource "aws_iam_role_policy_attachment" "terraform_runner_eks_describe" {
  role       = aws_iam_role.terraform_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# SSM to connect without SSH
resource "aws_iam_role_policy_attachment" "terraform_runner_ssm" {
  role       = aws_iam_role.terraform_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Additional permissions for Terraform (adjust as needed)
resource "aws_iam_role_policy" "terraform_runner_additional" {
  name = "${module.eks.cluster_name}-terraform-runner-policy"
  role = aws_iam_role.terraform_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "terraform_runner" {
  name = "${module.eks.cluster_name}-terraform-runner-profile"
  role = aws_iam_role.terraform_runner.name

  tags = local.tags
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
  value       = aws_instance.terraform_runner.id
}

output "connect_to_bastion" {
  description = "Command to connect to the bastion via SSM"
  value       = "aws ssm start-session --target ${aws_instance.terraform_runner.id} --region eu-central-1"
}

output "configure_kubectl_from_bastion" {
  description = "Command to run on bastion to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region eu-central-1"
}

output "instructions" {
  description = "Instructions for deploying kubernetes dependencies"
  value       = <<-EOT
    To deploy Kubernetes dependencies on this private cluster:

    1. Connect to the bastion:
       aws ssm start-session --target ${aws_instance.terraform_runner.id} --region eu-central-1

    2. On the bastion, configure kubectl:
       aws eks update-kubeconfig --name ${module.eks.cluster_name} --region eu-central-1

    3. Clone your terraform repository:
       cd /opt/terraform
       git clone <your-repo-url>

    4. Navigate to quix-eks-dependencies configuration:
       cd <your-repo>/k8s-dependencies

    5. Run terraform:
       terraform init
       terraform plan
       terraform apply

    Note: The bastion has Terraform, kubectl, and helm pre-installed.
  EOT
}
