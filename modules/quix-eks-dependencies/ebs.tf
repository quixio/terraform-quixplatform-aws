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
