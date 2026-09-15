variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "prod_subnetwork" {
  type = string
}

variable "gitops_pod_cidr" {
  type = string
}

variable "gitops_node_cidr" {
  type = string
}

variable "argo_service_account_email" {
  type = string
}
