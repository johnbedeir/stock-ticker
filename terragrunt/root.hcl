terraform_version_constraint  = ">= 1.15.5, < 1.16.0"
terragrunt_version_constraint = ">= 1.1.4, < 1.2.0"

locals {
  project_id   = "johnydev"
  region       = "us-east1"
  state_bucket = "johnydev-stock-ticker-tfstate"

  repository_owner = "johnbedeir"
  repository_name  = "stock-ticker"
  operator_cidr    = get_env("OPERATOR_CIDR")

  gke_prod_subnet_cidr     = "10.10.0.0/20"
  gke_prod_pods_cidr       = "10.20.0.0/16"
  gke_prod_services_cidr   = "10.30.0.0/20"
  gke_gitops_subnet_cidr   = "10.11.0.0/20"
  gke_gitops_pods_cidr     = "10.21.0.0/16"
  gke_gitops_services_cidr = "10.31.0.0/20"
}

remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    project              = local.project_id
    location             = local.region
    bucket               = local.state_bucket
    prefix               = path_relative_to_include()
    skip_bucket_creation = true
  }
}

generate "google_provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
  provider "google" {
    project = var.project_id
    region  = var.region
  }
  EOF
}
