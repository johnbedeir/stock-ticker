output "server_service_name" {
  description = "Private Argo CD server service."
  value       = "${helm_release.argocd.name}-server"
}

output "namespace" {
  description = "Argo CD namespace."
  value       = helm_release.argocd.namespace
}

output "application_name" {
  description = "Terraform-owned Argo CD Application name."
  value       = var.application_name
}
