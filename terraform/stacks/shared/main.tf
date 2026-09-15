terraform {
  required_version = ">= 1.15.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

variable "project_id" {
  description = "Google Cloud project ID for shared infrastructure."
  type        = string
}

variable "region" {
  description = "Google Cloud region for shared infrastructure."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to authenticate, in owner/repository form."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format."
  }
}

variable "network_name" {
  description = "Name of the shared VPC."
  type        = string
  default     = "stock-ticker"
}

variable "artifact_repository_id" {
  description = "ID of the Docker Artifact Registry repository."
  type        = string
  default     = "stock-ticker"
}

variable "chart_artifact_repository_id" {
  description = "ID of the OCI Helm chart Artifact Registry repository."
  type        = string
  default     = "stock-ticker-charts"
}

variable "gke_prod_subnet_cidr" {
  description = "Primary IPv4 CIDR for the gke-prod subnet."
  type        = string

  validation {
    condition     = can(cidrhost(var.gke_prod_subnet_cidr, 0))
    error_message = "gke_prod_subnet_cidr must be a valid CIDR."
  }
}

variable "gke_prod_pods_cidr" {
  description = "Secondary IPv4 CIDR for production GKE pods."
  type        = string

  validation {
    condition     = can(cidrhost(var.gke_prod_pods_cidr, 0))
    error_message = "gke_prod_pods_cidr must be a valid CIDR."
  }
}

variable "gke_prod_services_cidr" {
  description = "Secondary IPv4 CIDR for production GKE services."
  type        = string

  validation {
    condition     = can(cidrhost(var.gke_prod_services_cidr, 0))
    error_message = "gke_prod_services_cidr must be a valid CIDR."
  }
}

variable "gke_gitops_subnet_cidr" {
  description = "Primary IPv4 CIDR for the gke-gitops subnet."
  type        = string

  validation {
    condition     = can(cidrhost(var.gke_gitops_subnet_cidr, 0))
    error_message = "gke_gitops_subnet_cidr must be a valid CIDR."
  }
}

variable "gke_gitops_pods_cidr" {
  description = "Secondary IPv4 CIDR for GitOps GKE pods."
  type        = string

  validation {
    condition     = can(cidrhost(var.gke_gitops_pods_cidr, 0))
    error_message = "gke_gitops_pods_cidr must be a valid CIDR."
  }
}

variable "gke_gitops_services_cidr" {
  description = "Secondary IPv4 CIDR for GitOps GKE services."
  type        = string

  validation {
    condition     = can(cidrhost(var.gke_gitops_services_cidr, 0))
    error_message = "gke_gitops_services_cidr must be a valid CIDR."
  }
}

resource "google_project_service" "service_usage" {
  project            = var.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

locals {
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "sts.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project_service.service_usage]
}

data "google_project" "this" {
  project_id = var.project_id

  depends_on = [google_project_service.required]
}

module "network" {
  source = "../../modules/network"

  project_id               = var.project_id
  region                   = var.region
  network_name             = var.network_name
  gke_prod_subnet_cidr     = var.gke_prod_subnet_cidr
  gke_prod_pods_cidr       = var.gke_prod_pods_cidr
  gke_prod_services_cidr   = var.gke_prod_services_cidr
  gke_gitops_subnet_cidr   = var.gke_gitops_subnet_cidr
  gke_gitops_pods_cidr     = var.gke_gitops_pods_cidr
  gke_gitops_services_cidr = var.gke_gitops_services_cidr

  depends_on = [google_project_service.required]
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.artifact_repository_id

  depends_on = [google_project_service.required]
}

module "chart_artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.chart_artifact_repository_id
  description   = "OCI Helm charts for stock-ticker"

  depends_on = [google_project_service.required]
}

module "iam" {
  source = "../../modules/iam"

  project_id                         = var.project_id
  project_number                     = data.google_project.this.number
  github_repository                  = var.github_repository
  artifact_repository_name           = module.artifact_registry.repository_name
  artifact_repository_location       = module.artifact_registry.location
  chart_artifact_repository_name     = module.chart_artifact_registry.repository_name
  chart_artifact_repository_location = module.chart_artifact_registry.location

  depends_on = [google_project_service.required]
}

output "enabled_apis" {
  description = "APIs owned and enabled by this stack."
  value       = sort(concat([google_project_service.service_usage.service], [for service in google_project_service.required : service.service]))
}

output "project_id" {
  description = "Google Cloud project ID containing the shared resources."
  value       = var.project_id
}

output "region" {
  description = "Google Cloud region containing the shared regional resources."
  value       = var.region
}

output "network_id" {
  description = "ID of the shared VPC."
  value       = module.network.network_id
}

output "network_name" {
  description = "Name of the shared VPC."
  value       = module.network.network_name
}

output "network_self_link" {
  description = "Self-link of the shared VPC."
  value       = module.network.network_self_link
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value       = module.network.subnet_ids
}

output "subnet_self_links" {
  description = "Subnet self-links keyed by subnet name."
  value       = module.network.subnet_self_links
}

output "pod_secondary_range_names" {
  description = "Pod secondary range names keyed by subnet name."
  value       = module.network.pod_secondary_range_names
}

output "service_secondary_range_names" {
  description = "Service secondary range names keyed by subnet name."
  value       = module.network.service_secondary_range_names
}

output "nat_ip_address" {
  description = "Static public IPv4 address used by Cloud NAT."
  value       = module.network.nat_ip_address
}

output "artifact_repository_id" {
  description = "ID of the Docker Artifact Registry repository."
  value       = module.artifact_registry.repository_id
}

output "artifact_repository_resource_id" {
  description = "Terraform resource ID of the Docker Artifact Registry repository."
  value       = module.artifact_registry.repository_resource_id
}

output "artifact_repository_name" {
  description = "Full resource name of the Docker Artifact Registry repository."
  value       = module.artifact_registry.repository_name
}

output "artifact_repository_location" {
  description = "Location of the Docker Artifact Registry repository."
  value       = module.artifact_registry.location
}

output "artifact_repository_url" {
  description = "Docker repository hostname and path."
  value       = module.artifact_registry.repository_url
}

output "chart_artifact_repository_id" {
  description = "ID of the OCI Helm chart Artifact Registry repository."
  value       = module.chart_artifact_registry.repository_id
}

output "chart_artifact_repository_name" {
  description = "Full resource name of the OCI Helm chart Artifact Registry repository."
  value       = module.chart_artifact_registry.repository_name
}

output "chart_artifact_repository_location" {
  description = "Location of the OCI Helm chart Artifact Registry repository."
  value       = module.chart_artifact_registry.location
}

output "chart_artifact_repository_url" {
  description = "OCI Helm chart repository hostname and path."
  value       = module.chart_artifact_registry.repository_url
}

output "ci_service_account_email" {
  description = "Email address of the GitHub Actions CI service account."
  value       = module.iam.ci_service_account_email
}

output "argo_service_account_email" {
  description = "Email address of the future Argo service account."
  value       = module.iam.argo_service_account_email
}

output "workload_identity_pool_name" {
  description = "Full resource name of the GitHub workload identity pool."
  value       = module.iam.workload_identity_pool_name
}

output "workload_identity_provider_name" {
  description = "Full resource name used by GitHub Actions authentication."
  value       = module.iam.workload_identity_provider_name
}
