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

dependency "prod_addons" {
  config_path = "../../gke-prod/addons"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    prometheus_proxy_url            = "https://10.10.0.10"
    prometheus_proxy_username       = "grafana"
    prometheus_proxy_password       = "plan-only-placeholder"
    prometheus_proxy_ca_certificate = "plan-only-placeholder"
  }
}

dependencies {
  paths = ["../../shared"]
}

inputs = {
  project_id                     = include.root.locals.project_id
  region                         = include.root.locals.region
  cluster_name                   = "gke-gitops"
  cluster_endpoint               = dependency.cluster.outputs.endpoint
  cluster_ca_certificate         = dependency.cluster.outputs.cluster_ca_certificate
  prod_cluster_endpoint          = dependency.prod_cluster.outputs.endpoint
  prod_cluster_ca_certificate    = dependency.prod_cluster.outputs.cluster_ca_certificate
  prod_prometheus_url            = dependency.prod_addons.outputs.prometheus_proxy_url
  prod_prometheus_username       = dependency.prod_addons.outputs.prometheus_proxy_username
  prod_prometheus_password       = dependency.prod_addons.outputs.prometheus_proxy_password
  prod_prometheus_ca_certificate = dependency.prod_addons.outputs.prometheus_proxy_ca_certificate
}
