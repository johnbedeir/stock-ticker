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

  gke_prod_subnet_cidr     = include.root.locals.gke_prod_subnet_cidr
  gke_prod_pods_cidr       = include.root.locals.gke_prod_pods_cidr
  gke_prod_services_cidr   = include.root.locals.gke_prod_services_cidr
  gke_gitops_subnet_cidr   = include.root.locals.gke_gitops_subnet_cidr
  gke_gitops_pods_cidr     = include.root.locals.gke_gitops_pods_cidr
  gke_gitops_services_cidr = include.root.locals.gke_gitops_services_cidr
}
