output "namespace" {
  description = "Monitoring namespace."
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "prometheus_service_name" {
  description = "Cluster-local Prometheus service created by the chart."
  value       = "${helm_release.monitoring.name}-kube-prometheus-prometheus"
}

output "grafana_service_name" {
  description = "Cluster-local Grafana service name when Grafana is enabled."
  value       = var.grafana_enabled ? "${helm_release.monitoring.name}-grafana" : null
}
