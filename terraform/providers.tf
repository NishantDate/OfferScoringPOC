provider "aws" {
  region = var.region
  # Auth: use your SSO profile via AWS_PROFILE env (e.g., rokt-dev-admin),
  # or set shared_config_files/credentials if you prefer.
  default_tags {
    tags = {
      Project = var.project
      Env     = var.env
      IaC     = "terraform"
    }
  }
}