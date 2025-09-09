resource "kubectl_manifest" "gatewayclass_istio" {
  depends_on = [kubectl_manifest.gateway_api_crds, time_sleep.wait_for_crds]
  yaml_body  = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata: { name: istio }
    spec:
      controllerName: istio.io/gateway-controller
  YAML
}

# A shared, platform-owned Gateway in istio-system
resource "kubectl_manifest" "public_gateway" {
  depends_on = [kubectl_manifest.gateway_api_crds, time_sleep.wait_for_crds, kubectl_manifest.gatewayclass_istio]
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
}