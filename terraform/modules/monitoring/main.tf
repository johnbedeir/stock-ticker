locals {
  monitoring_label = {
    "monitoring.stock-ticker/enabled" = "true"
  }

  grafana_data_sources = [
    for data_source in [
      {
        name      = "GitOps"
        uid       = "gitops-prometheus"
        type      = "prometheus"
        access    = "proxy"
        url       = "http://monitoring-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local:9090"
        isDefault = true
        editable  = false
        jsonData = {
          httpMethod   = "POST"
          timeInterval = "30s"
        }
      },
      {
        name          = "Prod"
        uid           = "prod-prometheus"
        type          = "prometheus"
        access        = "proxy"
        url           = var.prod_prometheus_url
        basicAuth     = true
        basicAuthUser = var.prod_prometheus_username
        isDefault     = false
        editable      = false
        jsonData = {
          httpMethod        = "POST"
          timeInterval      = "30s"
          tlsAuthWithCACert = true
          tlsSkipVerify     = false
        }
        secureJsonData = {
          basicAuthPassword = var.prod_prometheus_password
          tlsCACert         = var.prod_prometheus_ca_certificate
        }
      }
  ] : data_source if var.grafana_enabled]

  grafana_dashboards = var.grafana_enabled && var.grafana_dashboard_json != "" ? {
    default = {
      multi-cluster = {
        json = var.grafana_dashboard_json
      }
    }
  } : {}

  chart_values = {
    crds = {
      enabled = true
    }

    kubeControllerManager = {
      enabled = false
    }
    kubeEtcd = {
      enabled = false
    }
    kubeProxy = {
      enabled = false
    }
    kubeScheduler = {
      enabled = false
    }

    prometheusOperator = {
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    }

    prometheus = {
      prometheusSpec = {
        externalLabels = {
          cluster = var.cluster_name
        }
        retention     = var.prometheus_retention
        retentionSize = var.prometheus_retention_size
        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
        serviceMonitorSelectorNilUsesHelmValues = false
        serviceMonitorSelector                  = {}
        serviceMonitorNamespaceSelector = {
          matchLabels = local.monitoring_label
        }
        podMonitorSelectorNilUsesHelmValues = false
        podMonitorSelector                  = {}
        podMonitorNamespaceSelector = {
          matchLabels = local.monitoring_label
        }
        ruleSelectorNilUsesHelmValues = false
        ruleSelector                  = {}
        ruleNamespaceSelector = {
          matchLabels = local.monitoring_label
        }
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "standard-rwo"
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = var.prometheus_storage_size
                }
              }
            }
          }
        }
      }
    }

    alertmanager = {
      enabled = true
      alertmanagerSpec = {
        retention = "120h"
        alertmanagerConfigSelector = {
          matchLabels = {
            "alertmanager.stock-ticker/enabled" = "true"
          }
        }
        alertmanagerConfigNamespaceSelector = {
          matchLabels = local.monitoring_label
        }
        alertmanagerConfigMatcherStrategy = {
          type = "None"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "250m"
            memory = "512Mi"
          }
        }
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "standard-rwo"
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = var.alertmanager_storage_size
                }
              }
            }
          }
        }
      }
    }

    grafana = {
      enabled = var.grafana_enabled
      service = {
        type = "ClusterIP"
      }
      persistence = {
        enabled          = var.grafana_enabled
        storageClassName = "standard-rwo"
        accessModes      = ["ReadWriteOnce"]
        size             = var.grafana_storage_size
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      sidecar = {
        datasources = {
          enabled                  = var.grafana_enabled
          defaultDatasourceEnabled = false
        }
        dashboards = {
          enabled         = var.grafana_enabled
          searchNamespace = var.namespace
        }
      }
      additionalDataSources = local.grafana_data_sources
      dashboardProviders = var.grafana_enabled ? {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      } : {}
      dashboards = local.grafana_dashboards
    }

    "kube-state-metrics" = {
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    }

    "prometheus-node-exporter" = {
      resources = {
        requests = {
          cpu    = "50m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
      }
    }
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name   = var.namespace
    labels = local.monitoring_label
  }
}

resource "helm_release" "monitoring" {
  name       = "monitoring"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version

  atomic          = true
  cleanup_on_fail = true
  timeout         = 900
  wait            = true

  values = [yamlencode(local.chart_values)]

  lifecycle {
    precondition {
      condition = !var.grafana_enabled || alltrue([
        var.prod_prometheus_url != "",
        var.prod_prometheus_username != "",
        var.prod_prometheus_password != "",
        var.prod_prometheus_ca_certificate != "",
      ])
      error_message = "Grafana requires the Prod Prometheus URL, credentials, and CA certificate."
    }
  }
}
