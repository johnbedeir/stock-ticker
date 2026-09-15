output "grafana_service_name" {
  description = "Private Grafana service used for operator port-forwarding."
  value       = module.monitoring.grafana_service_name
}

output "monitoring_namespace" {
  description = "Namespace containing the GitOps monitoring stack."
  value       = module.monitoring.namespace
}
