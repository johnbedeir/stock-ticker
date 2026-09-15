variable "namespace" {
  description = "Namespace in which Argo CD is installed."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Pinned argo-cd Helm chart version."
  type        = string
  default     = "8.2.4"
}

variable "argo_service_account_email" {
  description = "Google service account used by Argo CD for Prod GKE access."
  type        = string
}

variable "prod_cluster_name" {
  description = "Argo CD name for the production cluster."
  type        = string
  default     = "gke-prod"
}

variable "prod_cluster_endpoint" {
  description = "Production GKE API endpoint."
  type        = string
  sensitive   = true
}

variable "prod_cluster_ca_certificate" {
  description = "Base64-encoded production GKE CA certificate."
  type        = string
  sensitive   = true
}

variable "repository_url" {
  description = "Git repository containing the stock-ticker Helm chart."
  type        = string
}

variable "target_revision" {
  description = "Git revision watched by Argo CD."
  type        = string
  default     = "main"
}

variable "application_name" {
  description = "Argo CD Application and AppProject name."
  type        = string
  default     = "stock-ticker"
}

variable "application_namespace" {
  description = "Production namespace managed by the Application."
  type        = string
  default     = "stock-ticker"
}
