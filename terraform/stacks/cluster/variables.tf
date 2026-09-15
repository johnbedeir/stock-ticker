variable "project_id" {
  description = "Google Cloud project that owns the cluster."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
}

variable "region" {
  description = "GKE cluster region."
  type        = string
}

variable "node_locations" {
  description = "Explicit zones used by the regional node pool."
  type        = list(string)
}

variable "network" {
  description = "Dependency-provided VPC network name or self-link."
  type        = string
}

variable "subnetwork" {
  description = "Dependency-provided VPC subnetwork name or self-link."
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Dependency-provided Pod secondary range name."
  type        = string
}

variable "services_secondary_range_name" {
  description = "Dependency-provided Service secondary range name."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "RFC 1918 /28 CIDR reserved for the GKE control plane."
  type        = string
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to access the public control-plane endpoint."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"
}

variable "deletion_protection" {
  description = "Protect the cluster from accidental Terraform deletion."
  type        = bool
  default     = true
}

variable "node_service_account_id" {
  description = "Account ID for the dedicated node service account."
  type        = string
}

variable "artifact_registry_project_id" {
  description = "Dependency-provided project containing the image repository."
  type        = string
}

variable "artifact_registry_location" {
  description = "Dependency-provided Artifact Registry repository location."
  type        = string
}

variable "artifact_registry_repository" {
  description = "Dependency-provided Artifact Registry repository ID or full Terraform resource ID."
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
}

variable "total_max_node_count" {
  description = "Maximum total node count across all node locations."
  type        = number
}

variable "labels" {
  description = "Labels applied to the cluster and nodes."
  type        = map(string)
  default     = {}
}

variable "network_tags" {
  description = "Network tags applied to worker nodes."
  type        = list(string)
  default     = []
}
