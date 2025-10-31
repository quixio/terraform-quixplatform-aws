################################################################################
# Route 53 Hosted Zone
################################################################################

resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0

  name = var.domain_name

  tags = merge(
    local.tags,
    {
      Name = "${var.cluster_name}-hosted-zone"
      Type = "Public"
    }
  )
}

