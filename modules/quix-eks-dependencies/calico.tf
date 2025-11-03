################################################################################
# Calico Network Policy Engine via Helm
################################################################################
# Installs Calico using the Tigera operator for network policy enforcement
# on Amazon VPC CNI. This provides network policies without replacing the CNI.

resource "helm_release" "tigera_operator" {
  count = var.enable_calico ? 1 : 0

  name             = "tigera-operator"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  namespace        = "tigera-operator"
  create_namespace = true
  version          = "v3.28.2"

  values = [yamlencode({
    installation = {
      enabled            = true
      kubernetesProvider = "EKS"
      cni = {
        type = "AmazonVPC"
      }
      calicoNetwork = {
        bgp = "Disabled"
      }
    }
  })]
}
