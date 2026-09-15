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

variable "prod_cluster_endpoint" {
  type      = string
  sensitive = true
}

variable "prod_cluster_ca_certificate" {
  type      = string
  sensitive = true
}

variable "cluster_name" {
  type = string
}

variable "prod_prometheus_url" {
  type = string
}

variable "prod_prometheus_username" {
  type      = string
  sensitive = true
}

variable "prod_prometheus_password" {
  type      = string
  sensitive = true
}

variable "prod_prometheus_ca_certificate" {
  type      = string
  sensitive = true
}

variable "argo_service_account_email" {
  type = string
}

variable "prod_cluster_name" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "target_revision" {
  type    = string
  default = "main"
}
