variable "cluster_name" {
  description = "Name used to identify this cluster in metrics and alerts."
  type        = string
}

variable "namespace" {
  description = "Namespace in which to install the monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Pinned kube-prometheus-stack chart version."
  type        = string
  default     = "90.2.0"
}

variable "grafana_enabled" {
  description = "Whether Grafana is installed in this cluster."
  type        = bool
}

variable "grafana_dashboard_json" {
  description = "Optional dashboard JSON provisioned when Grafana is enabled."
  type        = string
  default     = ""
}

variable "prod_prometheus_url" {
  description = "Private HTTPS URL for the Prod Prometheus proxy."
  type        = string
  default     = ""
}

variable "prod_prometheus_username" {
  description = "Basic-auth username for the Prod Prometheus data source."
  type        = string
  default     = ""
  sensitive   = true
}

variable "prod_prometheus_password" {
  description = "Basic-auth password for the Prod Prometheus data source."
  type        = string
  default     = ""
  sensitive   = true
}

variable "prod_prometheus_ca_certificate" {
  description = "PEM certificate trusted by Grafana for Prod Prometheus."
  type        = string
  default     = ""
  sensitive   = true
}

variable "prometheus_retention" {
  description = "Time-based Prometheus retention."
  type        = string
  default     = "7d"
}

variable "prometheus_retention_size" {
  description = "Size-based Prometheus retention."
  type        = string
  default     = "15GB"
}

variable "prometheus_storage_size" {
  description = "Prometheus persistent volume size."
  type        = string
  default     = "20Gi"
}

variable "alertmanager_storage_size" {
  description = "Alertmanager persistent volume size."
  type        = string
  default     = "5Gi"
}

variable "grafana_storage_size" {
  description = "Grafana persistent volume size."
  type        = string
  default     = "5Gi"
}
