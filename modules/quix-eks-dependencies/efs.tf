################################################################################
# EFS CSI driver IAM role and Pod Identity association
################################################################################

resource "aws_iam_role" "efs_csi" {
  count = var.efs_csi_role_arn == null && var.enable_efs_csi_addon ? 1 : 0

  name        = "quix-efs-csi-${var.cluster_name}"
  description = "IAM role for EFS CSI controller via IRSA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.efs_csi_namespace}:${var.efs_csi_service_account}",
            "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, { Name = "quix-efs-csi-role" })
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  count = var.efs_csi_role_arn == null && var.enable_efs_csi_addon ? 1 : 0

  role       = aws_iam_role.efs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}




################################################################################
# EFS CSI driver via Helm
################################################################################

resource "helm_release" "efs_csi" {
  count = var.enable_efs_csi_addon ? 1 : 0

  name             = "aws-efs-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart            = "aws-efs-csi-driver"
  namespace        = var.efs_csi_namespace
  create_namespace = false

  values = [yamlencode({
    image = {
      repository = "${var.amazon_container_id}.dkr.ecr.${var.region}.amazonaws.com/eks/aws-efs-csi-driver"
    }
    controller = {
      volMetricsOptIn = true
      serviceAccount = {
        create = true
        name   = var.efs_csi_service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = var.efs_csi_role_arn != null ? var.efs_csi_role_arn : aws_iam_role.efs_csi[0].arn
        }
      }
    }
    node = {
      volMetricsOptIn = true
    }
  })]
}

################################################################################
# Kubernetes StorageClass for EFS (dynamic provisioning)
################################################################################

resource "kubernetes_storage_class_v1" "efs" {
  count = var.create_efs_storage_class && var.enable_efs_csi_addon ? 1 : 0

  metadata {
    name = var.efs_storage_class_name
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = var.efs_storage_class_reclaim_policy

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = var.efs_file_system_id
    directoryPerms   = "700"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    basePath         = "/dynamic"
  }

  lifecycle {
    precondition {
      condition     = var.efs_file_system_id != null && var.efs_file_system_id != ""
      error_message = "efs_file_system_id must be provided when create_efs_storage_class is enabled."
    }
  }
}

################################################################################
# Kubernetes StorageClass for EBS (gp3)
################################################################################

resource "kubernetes_storage_class_v1" "ebs" {
  count = var.create_ebs_storage_class ? 1 : 0

  metadata {
    name = var.ebs_storage_class_name
    annotations = var.ebs_storage_class_is_default ? {
      "storageclass.kubernetes.io/is-default-class" = "true"
    } : null
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = var.ebs_storage_class_reclaim_policy
  volume_binding_mode    = var.ebs_storage_class_volume_binding_mode
  allow_volume_expansion = var.ebs_storage_class_allow_volume_expansion

  parameters = {
    type = var.ebs_volume_type
  }
}
