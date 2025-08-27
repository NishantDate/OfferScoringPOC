variable "project" {
  type    = string
  default = "rokt-poc"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "rokt-poc-dev"
}

# Pick a supported EKS version; 1.31 is a safe default today.
variable "cluster_version" {
  type    = string
  default = "1.31"
} # You can use 1.33 if your account supports it. :contentReference[oaicite:1]{index=1}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az" {
  type    = string
  default = "us-east-1a"
} # single AZ to stay cheap

variable "instance_type" {
  type    = string
  default = "t4g.large"
}

variable "node_disk_gb" {
  type    = number
  default = 20
}
