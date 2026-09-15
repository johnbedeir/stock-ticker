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
  description = "Google Cloud project in which to create IAM resources."
  type        = string
}

variable "project_number" {
  description = "Numeric Google Cloud project number used in principal identifiers."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to federate, in owner/repository form."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format."
  }
}

variable "artifact_repository_name" {
  description = "Artifact Registry repository resource name to which CI receives writer access."
  type        = string
}

variable "artifact_repository_location" {
  description = "Location of the Artifact Registry repository."
  type        = string
}

variable "chart_artifact_repository_name" {
  description = "Artifact Registry repository resource name to which CI receives Helm chart writer access."
  type        = string
}

variable "chart_artifact_repository_location" {
  description = "Location of the Helm chart Artifact Registry repository."
  type        = string
}

variable "workload_identity_pool_id" {
  description = "ID of the GitHub Actions workload identity pool."
  type        = string
  default     = "github-actions"
}

variable "workload_identity_provider_id" {
  description = "ID of the GitHub Actions OIDC provider."
  type        = string
  default     = "github"
}

variable "ci_service_account_id" {
  description = "Account ID of the CI service account."
  type        = string
  default     = "stock-ticker-ci"
}

variable "argo_service_account_id" {
  description = "Account ID of the future Argo service account."
  type        = string
  default     = "stock-ticker-argo"
}

locals {
  artifact_repository_id = element(
    reverse(split("/", var.artifact_repository_name)),
    0,
  )
  chart_artifact_repository_id = element(
    reverse(split("/", var.chart_artifact_repository_name)),
    0,
  )
  argo_kubernetes_service_accounts = toset([
    "argocd-application-controller",
    "argocd-server",
  ])
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions"
  description               = "OIDC identities for ${var.github_repository}"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = "GitHub Actions"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}' && (assertion.ref == 'refs/heads/main' || assertion.ref.startsWith('refs/tags/v'))"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = var.ci_service_account_id
  display_name = "Stock ticker CI"
  description  = "Keyless GitHub Actions identity for publishing container images and Helm charts."
}

resource "google_service_account_iam_member" "ci_workload_identity_user" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/${var.github_repository}"
}

resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  project    = var.project_id
  location   = var.artifact_repository_location
  repository = local.artifact_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_artifact_registry_repository_iam_member" "ci_chart_writer" {
  project    = var.project_id
  location   = var.chart_artifact_repository_location
  repository = local.chart_artifact_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_service_account" "argo" {
  project      = var.project_id
  account_id   = var.argo_service_account_id
  display_name = "Stock ticker Argo"
  description  = "Future read-only GKE discovery identity for Argo."
}

resource "google_project_iam_member" "argo_cluster_viewer" {
  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${google_service_account.argo.email}"
}

resource "google_service_account_iam_member" "argo_workload_identity_user" {
  for_each = local.argo_kubernetes_service_accounts

  service_account_id = google_service_account.argo.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[argocd/${each.value}]"
}

output "ci_service_account_email" {
  description = "Email address of the CI service account."
  value       = google_service_account.ci.email
}

output "argo_service_account_email" {
  description = "Email address of the future Argo service account."
  value       = google_service_account.argo.email
}

output "workload_identity_pool_name" {
  description = "Full resource name of the GitHub workload identity pool."
  value       = google_iam_workload_identity_pool.github.name
}

output "workload_identity_provider_name" {
  description = "Full resource name used by GitHub Actions authentication."
  value       = google_iam_workload_identity_pool_provider.github.name
}
