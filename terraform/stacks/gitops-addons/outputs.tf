output "grafana_service_name" {
  description = "Private Grafana service used for operator port-forwarding."
  value       = module.monitoring.grafana_service_name
}

output "monitoring_namespace" {
  description = "Namespace containing the GitOps monitoring stack."
  value       = module.monitoring.namespace
}

output "argocd_server_service_name" {
  description = "Private Argo CD server service."
  value       = module.argocd.server_service_name
}

output "argocd_application_name" {
  description = "Terraform-owned production Application."
  value       = module.argocd.application_name
}
