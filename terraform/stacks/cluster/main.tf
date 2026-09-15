module "gke" {
  source = "../../modules/gke"

  project_id                    = var.project_id
  name                          = var.cluster_name
  region                        = var.region
  node_locations                = var.node_locations
  network                       = var.network
  subnetwork                    = var.subnetwork
  pods_secondary_range_name     = var.pods_secondary_range_name
  services_secondary_range_name = var.services_secondary_range_name
  master_ipv4_cidr_block        = var.master_ipv4_cidr_block
  master_authorized_cidrs       = var.master_authorized_cidrs
  release_channel               = var.release_channel
  deletion_protection           = var.deletion_protection

  node_service_account_id      = var.node_service_account_id
  artifact_registry_project_id = var.artifact_registry_project_id
  artifact_registry_location   = var.artifact_registry_location
  artifact_registry_repository = var.artifact_registry_repository

  machine_type         = var.machine_type
  disk_size_gb         = var.disk_size_gb
  disk_type            = var.disk_type
  image_type           = var.image_type
  total_min_node_count = var.total_min_node_count
  total_max_node_count = var.total_max_node_count
  labels               = var.labels
  network_tags         = var.network_tags
}
