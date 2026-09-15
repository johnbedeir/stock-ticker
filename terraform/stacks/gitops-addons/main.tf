locals {
  monitoring_label = {
    "monitoring.stock-ticker/enabled" = "true"
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name   = "argocd"
    labels = local.monitoring_label
  }
}

module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name    = var.cluster_name
  grafana_enabled = true

  grafana_dashboard_json         = file("${path.module}/dashboards/multi-cluster-overview.json")
  prod_prometheus_url            = var.prod_prometheus_url
  prod_prometheus_username       = var.prod_prometheus_username
  prod_prometheus_password       = var.prod_prometheus_password
  prod_prometheus_ca_certificate = var.prod_prometheus_ca_certificate
}
