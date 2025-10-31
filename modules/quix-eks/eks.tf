################################################################################
# EKS 
################################################################################

#EBS FAILS CAUSE NEEDS TO HAVE THE IAM ROLE ATTACHED

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" //21 changes some attributes

  cluster_name                = var.cluster_name
  cluster_version             = var.cluster_version
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    aws-ebs-csi-driver = {
      service_account_role_arn    = aws_iam_role.ebs_csi.arn
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      }),
    }
  }

  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }


  eks_managed_node_groups = { for key, pool in var.node_pools : key => {
    ami_type                   = "BOTTLEROCKET_x86_64"
    instance_types             = [pool.instance_size]
    min_size                   = pool.node_count
    max_size                   = pool.node_count
    desired_size               = pool.node_count
    node_repair_config         = { enabled = true }
    disk_size                  = pool.disk_size
    create_launch_template     = false
    use_custom_launch_template = false
    subnet_ids                 = var.singleaz != null ? [local.private_subnets_by_az[var.singleaz]] : module.vpc.private_subnets
    labels                     = pool.labels
    taints                     = pool.taints
    }
  }

  tags = local.tags
}


################################################################################ 
# Optional: fetch credentials locally
################################################################################


resource "null_resource" "createcontext" {
  count = var.enable_credentials_fetch ? 1 : 0
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
  }
  depends_on = [module.eks]
}
