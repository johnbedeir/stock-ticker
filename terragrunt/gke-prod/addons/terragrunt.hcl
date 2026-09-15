include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../terraform//stacks/prod-addons"
}

dependency "cluster" {
  config_path = "../cluster"
}

dependency "shared" {
  config_path = "../../shared"
}

inputs = {
  project_id                 = include.root.locals.project_id
  region                     = include.root.locals.region
  cluster_name               = "gke-prod"
  cluster_endpoint           = dependency.cluster.outputs.endpoint
  cluster_ca_certificate     = dependency.cluster.outputs.cluster_ca_certificate
  prod_subnetwork            = dependency.shared.outputs.subnet_self_links["gke-prod"]
  gitops_pod_cidr            = "10.21.0.0/16"
  gitops_node_cidr           = "10.11.0.0/20"
  argo_service_account_email = dependency.shared.outputs.argo_service_account_email
}
