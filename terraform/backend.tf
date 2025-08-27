terraform {
  backend "s3" {
    bucket = "sandbox-rokt-tfstates-h3ob52"
    key    = "${var.project}/terraform.tfstate"
    region = "us-east-1"
  }
}