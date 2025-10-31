
################################################################################
# IAM Policy for Route53 DNS access
################################################################################

resource "aws_iam_policy" "cert_manager_route53" {
  count = var.create_cert_manager_role ? 1 : 0

  name        = "quix-dns-access-to-${var.create_route53_zone ? aws_route53_zone.main[0].zone_id : "external"}"
  description = "Policy for cert-manager to manage Route53 DNS records"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = var.create_route53_zone ? "arn:aws:route53:::hostedzone/${aws_route53_zone.main[0].zone_id}" : "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect   = "Allow"
        Action   = "route53:ListHostedZonesByName"
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      Name    = "cert-manager-route53-policy"
      Purpose = "DNS validation for cert-manager"
    }
  )
}

################################################################################
# IAM Role for cert-manager
################################################################################

resource "aws_iam_role" "cert_manager" {
  count = var.create_cert_manager_role ? 1 : 0

  name        = "quix-certmanager-role-${var.create_route53_zone ? aws_route53_zone.main[0].zone_id : "external"}"
  description = "Role for cert-manager to access Route53 for DNS validation"

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
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.cert_manager_namespace}:${var.cert_manager_service_account}"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      Name    = "cert-manager-role"
      Purpose = "IRSA for cert-manager"
    }
  )
}

################################################################################
# Attach policy to role
################################################################################

resource "aws_iam_role_policy_attachment" "cert_manager" {
  count = var.create_cert_manager_role ? 1 : 0

  role       = aws_iam_role.cert_manager[0].name
  policy_arn = aws_iam_policy.cert_manager_route53[0].arn
}

