################################################################################
# EBS CSI driver IAM role (IRSA)
################################################################################

resource "aws_iam_role" "ebs_csi" {

  name        = "quix-ebs-csi-${module.eks.cluster_name}"
  description = "IAM role for EBS CSI controller via IRSA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.ebs_csi_namespace}:${var.ebs_csi_service_account}",
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, { Name = "quix-ebs-csi-role" })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

## Build KMS ARN from known parts to avoid unknown-count issues at plan time
locals {
  eks_kms_key_arn = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/${module.eks.kms_key_id}"
}

resource "aws_iam_policy" "ebs_kms" {
  count = var.attach_kms_permissions_to_ebs_role ? 1 : 0

  name        = "quix-ebs-csi-kms-${module.eks.cluster_name}"
  description = "KMS permissions for EBS CSI to use EKS CMK"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"],
        Resource = [local.eks_kms_key_arn],
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = true }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = [local.eks_kms_key_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_kms" {
  count      = var.attach_kms_permissions_to_ebs_role ? 1 : 0
  role       = aws_iam_role.ebs_csi.name
  policy_arn = aws_iam_policy.ebs_kms[0].arn
}



