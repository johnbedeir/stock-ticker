include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../terraform//stacks/shared"
}

inputs = {
  project_id                   = include.root.locals.project_id
  region                       = include.root.locals.region
  github_repository            = "${include.root.locals.repository_owner}/${include.root.locals.repository_name}"
  network_name                 = "stock-ticker"
  artifact_repository_id       = "stock-ticker"
  chart_artifact_repository_id = "stock-ticker-charts"

  gke_prod_subnet_cidr     = "10.10.0.0/20"
  gke_prod_pods_cidr       = "10.20.0.0/16"
  gke_prod_services_cidr   = "10.30.0.0/20"
  gke_gitops_subnet_cidr   = "10.11.0.0/20"
  gke_gitops_pods_cidr     = "10.21.0.0/16"
  gke_gitops_services_cidr = "10.31.0.0/20"
}
