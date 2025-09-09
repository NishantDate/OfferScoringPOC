terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.50" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.32" }
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
    http       = { source = "hashicorp/http", version = "~> 3.4" }
    kubectl    = { source = "gavinbunney/kubectl", version = "~> 1.14" } # for generic YAML/CRDs
    time       = { source = "hashicorp/time", version = "~> 0.9.1" }
  }
}
provider "aws" {
  region = var.region
}

# Use your existing EKS module outputs if you have them; otherwise use these data sources
# data "aws_eks_cluster" "this" { name = var.cluster_name }
data "aws_eks_cluster_auth" "this" {
  name     = var.cluster_name
  depends_on = [module.eks]
}

# locals {
#   host = data.aws_eks_cluster.this.endpoint
#   ca   = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
#   tok  = data.aws_eks_cluster_auth.this.token
# }

locals {
  host = module.eks.cluster_endpoint
  ca   = base64decode(module.eks.cluster_certificate_authority_data)
  tok  = data.aws_eks_cluster_auth.this.token
}

provider "kubernetes" {
  host                   = local.host
  cluster_ca_certificate = local.ca
  token                  = local.tok
}

provider "helm" {
  kubernetes {
    host                   = local.host
    cluster_ca_certificate = local.ca
    token                  = local.tok
  }
}

provider "kubectl" {
  host                   = local.host
  cluster_ca_certificate = local.ca
  token                  = local.tok
  load_config_file       = false
}