output "name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "location" {
  description = "GKE cluster region."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "Public control-plane endpoint restricted by the authorized CIDRs."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_service_account_email" {
  description = "Email address of the dedicated node service account."
  value       = google_service_account.nodes.email
}

output "sizing" {
  description = "Configured node-pool sizing."
  value = {
    machine_type         = var.machine_type
    disk_size_gb         = var.disk_size_gb
    total_min_node_count = var.total_min_node_count
    total_max_node_count = var.total_max_node_count
    node_locations       = var.node_locations
  }
}
