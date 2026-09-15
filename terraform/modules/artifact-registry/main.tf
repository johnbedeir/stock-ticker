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
  description = "Google Cloud project in which to create the repository."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the repository."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID."
  type        = string
}

variable "description" {
  description = "Human-readable repository description."
  type        = string
  default     = "Stock ticker container images"
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"

  docker_config {
    immutable_tags = true
  }
}

output "repository_id" {
  description = "Artifact Registry repository ID."
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_resource_id" {
  description = "Terraform resource ID of the Artifact Registry repository."
  value       = google_artifact_registry_repository.this.id
}

output "repository_name" {
  description = "Repository resource name."
  value       = google_artifact_registry_repository.this.name
}

output "repository_url" {
  description = "Docker repository hostname and path."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}

output "location" {
  description = "Repository location."
  value       = google_artifact_registry_repository.this.location
}
