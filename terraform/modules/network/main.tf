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
  description = "Google Cloud project in which to create the network."
  type        = string
}

variable "region" {
  description = "Google Cloud region for subnets, router, NAT, and NAT IP."
  type        = string
}

variable "network_name" {
  description = "Name of the custom-mode VPC."
  type        = string
}

variable "gke_prod_subnet_cidr" {
  description = "Primary IPv4 CIDR for the gke-prod subnet."
  type        = string
}

variable "gke_prod_pods_cidr" {
  description = "Secondary IPv4 CIDR for production GKE pods."
  type        = string
}

variable "gke_prod_services_cidr" {
  description = "Secondary IPv4 CIDR for production GKE services."
  type        = string
}

variable "gke_gitops_subnet_cidr" {
  description = "Primary IPv4 CIDR for the gke-gitops subnet."
  type        = string
}

variable "gke_gitops_pods_cidr" {
  description = "Secondary IPv4 CIDR for GitOps GKE pods."
  type        = string
}

variable "gke_gitops_services_cidr" {
  description = "Secondary IPv4 CIDR for GitOps GKE services."
  type        = string
}

locals {
  subnets = {
    gke-prod = {
      primary_cidr  = var.gke_prod_subnet_cidr
      pods_cidr     = var.gke_prod_pods_cidr
      services_cidr = var.gke_prod_services_cidr
    }
    gke-gitops = {
      primary_cidr  = var.gke_gitops_subnet_cidr
      pods_cidr     = var.gke_gitops_pods_cidr
      services_cidr = var.gke_gitops_services_cidr
    }
  }
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  for_each = local.subnets

  project                  = var.project_id
  region                   = var.region
  name                     = each.key
  network                  = google_compute_network.this.id
  ip_cidr_range            = each.value.primary_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "${each.key}-pods"
    ip_cidr_range = each.value.pods_cidr
  }

  secondary_ip_range {
    range_name    = "${each.key}-services"
    ip_cidr_range = each.value.services_cidr
  }
}

resource "google_compute_address" "nat" {
  project      = var.project_id
  region       = var.region
  name         = "${var.network_name}-nat-ip"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

resource "google_compute_router" "this" {
  project = var.project_id
  region  = var.region
  name    = "${var.network_name}-router"
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  region                             = var.region
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

output "network_id" {
  description = "ID of the VPC network."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Name of the VPC network."
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "Self-link of the VPC network."
  value       = google_compute_network.this.self_link
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value       = { for name, subnet in google_compute_subnetwork.this : name => subnet.id }
}

output "subnet_self_links" {
  description = "Subnet self-links keyed by subnet name."
  value       = { for name, subnet in google_compute_subnetwork.this : name => subnet.self_link }
}

output "pod_secondary_range_names" {
  description = "Pod secondary range names keyed by subnet name."
  value       = { for name in keys(local.subnets) : name => "${name}-pods" }
}

output "service_secondary_range_names" {
  description = "Service secondary range names keyed by subnet name."
  value       = { for name in keys(local.subnets) : name => "${name}-services" }
}

output "nat_ip_address" {
  description = "Static public IPv4 address used by Cloud NAT."
  value       = google_compute_address.nat.address
}
