include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../terraform//stacks/gitops-addons"
}

dependency "cluster" {
  config_path = "../cluster"
}

dependency "prod_cluster" {
  config_path = "../../gke-prod/cluster"
}

dependencies {
  paths = ["../../shared"]
}

inputs = {
  project_id                  = include.root.locals.project_id
  region                      = include.root.locals.region
  cluster_endpoint            = dependency.cluster.outputs.endpoint
  cluster_ca_certificate      = dependency.cluster.outputs.cluster_ca_certificate
  prod_cluster_endpoint       = dependency.prod_cluster.outputs.endpoint
  prod_cluster_ca_certificate = dependency.prod_cluster.outputs.cluster_ca_certificate
}
