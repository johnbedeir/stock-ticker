output "prometheus_proxy_url" {
  description = "Private HTTPS URL used by GitOps Grafana."
  value       = "https://${google_compute_address.prometheus_proxy.address}"
}

output "prometheus_proxy_username" {
  description = "Basic-auth username used by GitOps Grafana."
  value       = local.prometheus_proxy_username
  sensitive   = true
}

output "prometheus_proxy_password" {
  description = "Basic-auth password used by GitOps Grafana."
  value       = random_password.prometheus_proxy.result
  sensitive   = true
}

output "prometheus_proxy_ca_certificate" {
  description = "PEM certificate trusted by GitOps Grafana."
  value       = tls_self_signed_cert.prometheus_proxy.cert_pem
  sensitive   = true
}
