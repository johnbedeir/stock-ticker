variable "project_id" {
  description = "Google Cloud project that owns the GKE cluster."
  type        = string
}

variable "name" {
  description = "GKE cluster name."
  type        = string
}

variable "region" {
  description = "Region in which to create the regional cluster."
  type        = string
}

variable "node_locations" {
  description = "Explicit zones in which cluster nodes may run."
  type        = list(string)

  validation {
    condition     = length(var.node_locations) > 0
    error_message = "node_locations must contain at least one zone."
  }
}

variable "network" {
  description = "VPC network name or self-link."
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork name or self-link."
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Subnetwork secondary range used for Pod IP addresses."
  type        = string
}

variable "services_secondary_range_name" {
  description = "Subnetwork secondary range used for Service IP addresses."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "RFC 1918 /28 CIDR reserved for the GKE control plane."
  type        = string
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to reach the public control-plane endpoint."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))

  validation {
    condition     = length(var.master_authorized_cidrs) > 0
    error_message = "At least one master authorized CIDR is required."
  }
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "EXTENDED"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, STABLE, or EXTENDED."
  }
}

variable "deletion_protection" {
  description = "Protect the cluster from accidental Terraform deletion."
  type        = bool
  default     = true
}

variable "node_service_account_id" {
  description = "Account ID for the dedicated node service account."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.node_service_account_id))
    error_message = "node_service_account_id must be a valid 6-30 character service account ID."
  }
}

variable "artifact_registry_project_id" {
  description = "Project containing the Artifact Registry repository."
  type        = string
}

variable "artifact_registry_location" {
  description = "Location of the Artifact Registry repository."
  type        = string
}

variable "artifact_registry_repository" {
  description = "Repository ID or full Terraform resource ID from which nodes may pull images."
  type        = string
}

variable "machine_type" {
  description = "Machine type for worker nodes."
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "Boot disk size for worker nodes."
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Boot disk type for worker nodes."
  type        = string
  default     = "pd-balanced"
}

variable "image_type" {
  description = "Node operating system image."
  type        = string
  default     = "COS_CONTAINERD"
}

variable "total_min_node_count" {
  description = "Minimum total node count across all node locations."
  type        = number

  validation {
    condition     = var.total_min_node_count >= 0
    error_message = "total_min_node_count cannot be negative."
  }
}

variable "total_max_node_count" {
  description = "Maximum total node count across all node locations."
  type        = number

  validation {
    condition     = var.total_max_node_count > 0
    error_message = "total_max_node_count must be positive."
  }
}

variable "labels" {
  description = "Labels applied to the cluster and node pool."
  type        = map(string)
  default     = {}
}

variable "network_tags" {
  description = "Network tags applied to worker nodes."
  type        = list(string)
  default     = []
}
