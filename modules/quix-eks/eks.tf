################################################################################
# EKS 
################################################################################

#EBS FAILS CAUSE NEEDS TO HAVE THE IAM ROLE ATTACHED

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                        = var.cluster_name
  kubernetes_version          = var.cluster_version
  create_cloudwatch_log_group = false
  enabled_log_types           = []

  # EKS Addons
  # before_compute = true ensures these are created BEFORE node groups
  # This is critical - nodes need vpc-cni to get IPs and become Ready
  addons = {
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      }),
    }
    kube-proxy = {
      before_compute = true
    }
    coredns = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn    = aws_iam_role.ebs_csi.arn
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  vpc_id                                   = local.vpc_id
  subnet_ids                               = local.private_subnet_ids
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  endpoint_public_access                   = var.cluster_endpoint_public_access
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
    subnet_ids                 = var.singleaz != null ? [local.private_subnets_by_az[var.singleaz]] : local.private_subnet_ids
    labels                     = pool.labels
    taints = { for idx, taint in pool.taints : "${taint.key}-${idx}" => {
      key    = taint.key
      value  = taint.value
      effect = taint.effect
    } }
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
