# resource "kubernetes_namespace" "istio_system" {
#   metadata {
#     name = "istio-system"
#   }
# }

# # Base CRDs
# resource "helm_release" "istio_base" {
#   name       = "istio-base"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "base"
#   namespace  = kubernetes_namespace.istio_system.metadata[0].name
#   version    = var.istio_chart_version
#   depends_on = [kubectl_manifest.gateway_api_crds, time_sleep.wait_for_crds]
# }

# # Istiod (control plane)
# resource "helm_release" "istiod" {
#   name       = "istiod"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "istiod"
#   namespace  = kubernetes_namespace.istio_system.metadata[0].name
#   version    = var.istio_chart_version
#   wait       = true
#   timeout    = 600
#   depends_on = [helm_release.istio_base]
# }

# # Internet-facing ingress gateway (AWS NLB)
# resource "helm_release" "istio_ingress" {
#   name       = "istio-ingressgateway"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "gateway"
#   namespace  = kubernetes_namespace.istio_system.metadata[0].name
#   version    = var.istio_chart_version
#   wait       = false
#   timeout    = 600
#   depends_on = [helm_release.istiod]

#   values = [<<-YAML
#     service:
#       type: LoadBalancer
#       annotations:
#         service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
#         service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
#   YAML
#   ]
# }

# # Fetch the Service object for that output
# data "kubernetes_service" "istio_ingress" {
#   metadata {
#     name      = helm_release.istio_ingress.name
#     namespace = kubernetes_namespace.istio_system.metadata[0].name
#   }
# }
# # Useful output: external hostname of the NLB
# output "istio_ingress_hostname" {
#   depends_on = [data.kubernetes_service.istio_ingress]
#   value = try(
#     data.kubernetes_service.istio_ingress.status[0].load_balancer[0].ingress[0].hostname,
#     null
#   )
# }

