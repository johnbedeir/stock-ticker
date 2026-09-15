include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../terraform//stacks/cluster"
}

dependency "shared" {
  config_path = "../../shared"
}

inputs = {
  project_id   = include.root.locals.project_id
  region       = include.root.locals.region
  cluster_name = "gke-prod"

  node_locations                = ["us-east1-b", "us-east1-c"]
  network                       = dependency.shared.outputs.network_self_link
  subnetwork                    = dependency.shared.outputs.subnet_self_links["gke-prod"]
  pods_secondary_range_name     = dependency.shared.outputs.pod_secondary_range_names["gke-prod"]
  services_secondary_range_name = dependency.shared.outputs.service_secondary_range_names["gke-prod"]
  master_ipv4_cidr_block        = "172.16.0.16/28"
  master_authorized_cidrs = [
    {
      cidr_block   = include.root.locals.operator_cidr
      display_name = "operator"
    },
    {
      cidr_block   = "${dependency.shared.outputs.nat_ip_address}/32"
      display_name = "private-node-nat"
    },
  ]

  node_service_account_id      = "stock-ticker-prod-nodes"
  artifact_registry_project_id = dependency.shared.outputs.project_id
  artifact_registry_location   = dependency.shared.outputs.artifact_repository_location
  artifact_registry_repository = dependency.shared.outputs.artifact_repository_resource_id
  machine_type                 = "e2-standard-2"
  total_min_node_count         = 1
  total_max_node_count         = 3
  release_channel              = "REGULAR"
  deletion_protection          = true
  labels = {
    application = "stock-ticker"
    environment = "production"
    role        = "workload"
  }
  network_tags = ["gke-prod-nodes"]
}
