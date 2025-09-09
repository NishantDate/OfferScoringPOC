locals {
  name       = "${var.project}-${var.env}"
  public_sn  = cidrsubnet(var.vpc_cidr, 8, 0) # /24 from the /16
  public_sn2 = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  istio_chart_url     = "https://istio-release.storage.googleapis.com/charts"
}

data "aws_caller_identity" "current" {}

# ---------- Random suffix for globally-unique bucket names ----------
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# ---------- VPC (public-only, no NAT) ----------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs                  = var.azs
  public_subnets       = [local.public_sn, local.public_sn2]
  private_subnets      = []    # none
  enable_nat_gateway   = false # no NAT (cheap)
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Instances launched into these subnets get public IPs so they can egress via IGW
  map_public_ip_on_launch = true
}

# ---------- EKS Cluster ----------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  enable_irsa = true

  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = false
  enable_cluster_creator_admin_permissions = true


  # Minimal add-ons (you can pin versions if you want)
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  # One tiny managed node group on Graviton + AL2023
  eks_managed_node_groups = {
    default = {
      name           = "ng-1"
      ami_type       = "AL2023_ARM_64_STANDARD" # Graviton + AL2023 (matches our cheap plan). :contentReference[oaicite:2]{index=2}
      capacity_type  = "ON_DEMAND"
      instance_types = [var.instance_type]
      min_size       = 1
      desired_size   = 1
      max_size       = 1
      disk_size      = var.node_disk_gb
      labels         = { arch = "arm64" }
      subnet_ids     = module.vpc.public_subnets
    }
  }
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.21.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  helm_releases = {
    istio-base = {
      chart         = "base"
      chart_version = var.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istio-base"
      namespace     = "istio-system"
      create_namespace = true
    }

    istiod = {
      chart         = "istiod"
      chart_version = var.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istiod"
      namespace     = "istio-system"
      create_namespace = true

      set = [
        {
          name  = "meshConfig.accessLogFile"
          value = "/dev/stdout"
        }
      ]
    }

    istio-ingress = {
      chart            = "gateway"
      chart_version    = var.istio_chart_version
      repository       = local.istio_chart_url
      name             = "istio-ingress"
      namespace        = "istio-ingress" # per https://github.com/istio/istio/blob/master/manifests/charts/gateways/istio-ingress/values.yaml#L2
      create_namespace = true

      values = [
        yamlencode(
          {
            labels = {
              istio = "ingressgateway"
            }
            service = {
              annotations = {
                "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
                "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
                "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
                "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
              }
            }
          }
        )
      ]
    }
  }
}

# ---------- ECR repositories ----------
resource "aws_ecr_repository" "offers_api" {
  name                 = "offers-api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "spark_job" {
  name                 = "spark-job"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

# ---------- S3 buckets (features & logs), private + SSE ----------
resource "aws_s3_bucket" "features" {
  bucket        = "${var.project}-${var.env}-features-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project}-${var.env}-logs-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "features" {
  bucket                  = aws_s3_bucket.features.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "features" {
  bucket = aws_s3_bucket.features.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# ---------- Outputs ----------

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}
