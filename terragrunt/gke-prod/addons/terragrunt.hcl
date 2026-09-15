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

dependencies {
  paths = ["../../shared"]
}

inputs = {
  project_id             = include.root.locals.project_id
  region                 = include.root.locals.region
  cluster_endpoint       = dependency.cluster.outputs.endpoint
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
}
