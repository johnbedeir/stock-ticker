output "name" {
  description = "GKE cluster name."
  value       = module.gke.name
}

output "location" {
  description = "GKE cluster region."
  value       = module.gke.location
}

output "endpoint" {
  description = "Public control-plane endpoint restricted by the authorized CIDRs."
  value       = module.gke.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "node_service_account_email" {
  description = "Email address of the dedicated node service account."
  value       = module.gke.node_service_account_email
}

output "sizing" {
  description = "Configured node-pool sizing."
  value       = module.gke.sizing
}
