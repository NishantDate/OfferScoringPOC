locals { create_allow = length(trimspace(var.allow_cidr)) > 0 }

resource "kubectl_manifest" "allow_my_ip" {
  yaml_body  = <<-YAML
    apiVersion: security.istio.io/v1
    kind: AuthorizationPolicy
    metadata:
      name: allow-my-ip
      namespace: istio-system
    spec:
      selector:
        matchLabels:
          istio: ingressgateway
      action: ALLOW
      rules:
      - from:
        - source:
            ipBlocks:
            - "${var.allow_cidr}"
  YAML
  depends_on = [helm_release.istio_ingress]
}