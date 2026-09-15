locals {
  monitoring_label = {
    "monitoring.stock-ticker/enabled" = "true"
  }
  proxy_labels = {
    "app.kubernetes.io/name"      = "prometheus-proxy"
    "app.kubernetes.io/instance"  = "prod"
    "app.kubernetes.io/component" = "monitoring"
  }
  prometheus_proxy_username = "grafana"
}

module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name    = var.cluster_name
  grafana_enabled = false
}

resource "kubernetes_namespace_v1" "stock_ticker" {
  metadata {
    name   = "stock-ticker"
    labels = local.monitoring_label
  }
}

resource "kubernetes_role_v1" "argo_stock_ticker" {
  metadata {
    name      = "argocd-application-manager"
    namespace = kubernetes_namespace_v1.stock_ticker.metadata[0].name
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "services"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.gke.io"]
    resources  = ["managedcertificates"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["monitoring.coreos.com"]
    resources  = ["servicemonitors"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "argo_stock_ticker" {
  metadata {
    name      = "argocd-application-manager"
    namespace = kubernetes_namespace_v1.stock_ticker.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.argo_stock_ticker.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.argo_service_account_email
  }
}

resource "google_compute_address" "prometheus_proxy" {
  project      = var.project_id
  region       = var.region
  name         = "gke-prod-prometheus"
  address_type = "INTERNAL"
  subnetwork   = var.prod_subnetwork
}

resource "google_compute_global_address" "stock_ticker" {
  project = var.project_id
  name    = "stock-ticker-prod"
}

resource "random_password" "prometheus_proxy" {
  length  = 32
  special = false
}

resource "tls_private_key" "prometheus_proxy" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "prometheus_proxy" {
  private_key_pem = tls_private_key.prometheus_proxy.private_key_pem

  subject {
    common_name  = google_compute_address.prometheus_proxy.address
    organization = "stock-ticker"
  }

  ip_addresses          = [google_compute_address.prometheus_proxy.address]
  validity_period_hours = 8760
  early_renewal_hours   = 720
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "kubernetes_secret_v1" "prometheus_proxy_tls" {
  metadata {
    name      = "prometheus-proxy-tls"
    namespace = module.monitoring.namespace
  }

  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = tls_self_signed_cert.prometheus_proxy.cert_pem
    "tls.key" = tls_private_key.prometheus_proxy.private_key_pem
  }
}

resource "kubernetes_secret_v1" "prometheus_proxy_auth" {
  metadata {
    name      = "prometheus-proxy-auth"
    namespace = module.monitoring.namespace
  }

  data = {
    auth = "${local.prometheus_proxy_username}:${bcrypt(random_password.prometheus_proxy.result)}"
  }

  lifecycle {
    # bcrypt uses a random salt. Ignore re-hashing until credentials are
    # intentionally rotated by replacing this secret and the password.
    ignore_changes = [data]
  }
}

resource "kubernetes_config_map_v1" "prometheus_proxy" {
  metadata {
    name      = "prometheus-proxy"
    namespace = module.monitoring.namespace
  }

  data = {
    "nginx.conf" = <<-EOF
      pid /tmp/nginx.pid;
      events {}
      http {
        client_body_temp_path /tmp/client_temp;
        proxy_temp_path /tmp/proxy_temp;
        fastcgi_temp_path /tmp/fastcgi_temp;
        uwsgi_temp_path /tmp/uwsgi_temp;
        scgi_temp_path /tmp/scgi_temp;

        server {
          listen 8443 ssl;
          ssl_certificate /etc/nginx/tls/tls.crt;
          ssl_certificate_key /etc/nginx/tls/tls.key;
          ssl_protocols TLSv1.2 TLSv1.3;

          location = /healthz {
            access_log off;
            auth_basic off;
            return 200;
          }

          location / {
            auth_basic "Prometheus";
            auth_basic_user_file /etc/nginx/auth/auth;
            proxy_pass http://${module.monitoring.prometheus_service_name}.${module.monitoring.namespace}.svc.cluster.local:9090;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto https;
          }
        }
      }
    EOF
  }
}

resource "kubernetes_deployment_v1" "prometheus_proxy" {
  metadata {
    name      = "prometheus-proxy"
    namespace = module.monitoring.namespace
    labels    = local.proxy_labels
  }

  spec {
    replicas = 2

    selector {
      match_labels = local.proxy_labels
    }

    template {
      metadata {
        labels = local.proxy_labels
      }

      spec {
        automount_service_account_token = false

        security_context {
          run_as_non_root = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name    = "nginx"
          image   = "nginx:1.29.1-alpine@sha256:42a516af16b852e33b7682d5ef8acbd5d13fe08fecadc7ed98605ba5e3b26ab8"
          command = ["nginx"]
          args    = ["-g", "daemon off;"]

          port {
            name           = "https"
            container_port = 8443
          }

          resources {
            requests = {
              cpu    = "25m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 101
            run_as_group               = 101

            capabilities {
              drop = ["ALL"]
            }
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = "https"
              scheme = "HTTPS"
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = "https"
              scheme = "HTTPS"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
            read_only  = true
          }

          volume_mount {
            name       = "tls"
            mount_path = "/etc/nginx/tls"
            read_only  = true
          }

          volume_mount {
            name       = "auth"
            mount_path = "/etc/nginx/auth"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.prometheus_proxy.metadata[0].name
          }
        }

        volume {
          name = "tls"
          secret {
            secret_name = kubernetes_secret_v1.prometheus_proxy_tls.metadata[0].name
          }
        }

        volume {
          name = "auth"
          secret {
            secret_name = kubernetes_secret_v1.prometheus_proxy_auth.metadata[0].name
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "prometheus_proxy" {
  metadata {
    name      = "prometheus-proxy"
    namespace = module.monitoring.namespace
    annotations = {
      "networking.gke.io/load-balancer-type" = "Internal"
    }
  }

  spec {
    selector                    = local.proxy_labels
    type                        = "LoadBalancer"
    load_balancer_ip            = google_compute_address.prometheus_proxy.address
    load_balancer_source_ranges = [var.gitops_pod_cidr, var.gitops_node_cidr]
    external_traffic_policy     = "Cluster"

    port {
      name        = "https"
      port        = 443
      target_port = "https"
      protocol    = "TCP"
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg"],
      metadata[0].annotations["networking.gke.io/backend-service"],
    ]
  }
}
