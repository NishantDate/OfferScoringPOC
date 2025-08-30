resource "kubectl_manifest" "gatewayclass_istio" {
  yaml_body  = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata: { name: istio }
    spec:
      controllerName: istio.io/gateway-controller
  YAML
  depends_on = [helm_release.istiod]
}

# A shared, platform-owned Gateway in istio-system
resource "kubectl_manifest" "public_gateway" {
  yaml_body  = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: public-gw
      namespace: istio-system
    spec:
      gatewayClassName: istio
      listeners:
      - name: http
        protocol: HTTP
        port: ${var.gateway_listen_port}
        allowedRoutes:
          namespaces:
            from: All
  YAML
  depends_on = [kubectl_manifest.gatewayclass_istio, helm_release.istio_ingress]
}