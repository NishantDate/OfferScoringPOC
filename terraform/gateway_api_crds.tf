locals {
  gateway_api_version = "v1.0.0"
}

# Fetch Gateway API CRDs using HTTP provider
data "http" "gateway_api_crds" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml"
}

data "http" "gateway_crds" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml"
}

data "http" "httproute_crds" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml"
}

# Apply individual CRDs
resource "kubectl_manifest" "gateway_api_crds" {
  yaml_body = data.http.gateway_api_crds.response_body
  server_side_apply = true
  wait = true
}

resource "kubectl_manifest" "gateway_crds" {
  yaml_body = data.http.gateway_crds.response_body
  server_side_apply = true
  wait = true
  depends_on = [kubectl_manifest.gateway_api_crds]
}

resource "kubectl_manifest" "httproute_crds" {
  yaml_body = data.http.httproute_crds.response_body
  server_side_apply = true
  wait = true
  depends_on = [kubectl_manifest.gateway_crds]
}

resource "time_sleep" "wait_for_crds" {
  depends_on = [
    kubectl_manifest.gateway_api_crds,
    kubectl_manifest.gateway_crds,
    kubectl_manifest.httproute_crds
  ]
  create_duration = "30s"
}