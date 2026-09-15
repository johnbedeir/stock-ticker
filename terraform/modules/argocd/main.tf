locals {
  prod_server = "https://${var.prod_cluster_endpoint}"

  workload_identity_annotation = {
    "iam.gke.io/gcp-service-account" = var.argo_service_account_email
  }

  service_monitor = {
    enabled  = true
    interval = "30s"
  }

  namespace_resource_whitelist = [
    {
      group = ""
      kind  = "ConfigMap"
    },
    {
      group = ""
      kind  = "Service"
    },
    {
      group = "apps"
      kind  = "Deployment"
    },
    {
      group = "autoscaling"
      kind  = "HorizontalPodAutoscaler"
    },
    {
      group = "monitoring.coreos.com"
      kind  = "ServiceMonitor"
    },
    {
      group = "networking.gke.io"
      kind  = "ManagedCertificate"
    },
    {
      group = "networking.k8s.io"
      kind  = "Ingress"
    },
    {
      group = "policy"
      kind  = "PodDisruptionBudget"
    },
  ]

  extra_objects = [
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "AppProject"
      metadata = {
        name      = var.application_name
        namespace = var.namespace
      }
      spec = {
        description = "Restricted stock-ticker production deployment"
        sourceRepos = [var.repository_url]
        destinations = [
          {
            namespace = var.application_namespace
            server    = local.prod_server
          }
        ]
        clusterResourceWhitelist   = []
        namespaceResourceWhitelist = local.namespace_resource_whitelist
      }
    },
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name       = var.application_name
        namespace  = var.namespace
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
      }
      spec = {
        project = var.application_name
        source = {
          repoURL        = var.repository_url
          targetRevision = var.target_revision
          path           = "helm/stock-ticker-chart"
          helm = {
            valueFiles = ["values.yaml"]
          }
        }
        destination = {
          server    = local.prod_server
          namespace = var.application_namespace
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          syncOptions = [
            "ApplyOutOfSyncOnly=true",
            "CreateNamespace=false",
            "PruneLast=true",
          ]
          retry = {
            limit = 5
            backoff = {
              duration    = "5s"
              factor      = 2
              maxDuration = "3m"
            }
          }
        }
      }
    },
  ]

  chart_values = {
    global = {
      image = {
        repository = "quay.io/argoproj/argocd"
        tag        = "v3.0.12"
      }
    }

    controller = {
      serviceAccount = {
        create                       = true
        name                         = "argocd-application-controller"
        annotations                  = local.workload_identity_annotation
        automountServiceAccountToken = true
      }
      metrics = {
        enabled        = true
        serviceMonitor = local.service_monitor
      }
    }

    server = {
      serviceAccount = {
        create                       = true
        name                         = "argocd-server"
        annotations                  = local.workload_identity_annotation
        automountServiceAccountToken = true
      }
      service = {
        type = "ClusterIP"
      }
      metrics = {
        enabled        = true
        serviceMonitor = local.service_monitor
      }
    }

    repoServer = {
      serviceAccount = {
        create                       = true
        name                         = "argocd-repo-server"
        automountServiceAccountToken = false
      }
      metrics = {
        enabled        = true
        serviceMonitor = local.service_monitor
      }
    }

    applicationSet = {
      serviceAccount = {
        create                       = true
        name                         = "argocd-applicationset-controller"
        automountServiceAccountToken = true
      }
      metrics = {
        enabled        = true
        serviceMonitor = local.service_monitor
      }
    }

    notifications = {
      serviceAccount = {
        create                       = true
        name                         = "argocd-notifications-controller"
        automountServiceAccountToken = true
      }
      metrics = {
        enabled        = true
        serviceMonitor = local.service_monitor
      }
    }

    redis = {
      serviceAccount = {
        create                       = true
        name                         = "argocd-redis"
        automountServiceAccountToken = false
      }
    }

    dex = {
      enabled = false
    }

    configs = {
      params = {
        "server.insecure" = false
      }
      cm = {
        "application.instanceLabelKey" = "argocd.argoproj.io/instance"
      }
      clusterCredentials = {
        (var.prod_cluster_name) = {
          server           = local.prod_server
          namespaces       = var.application_namespace
          clusterResources = false
          project          = var.application_name
          config = {
            execProviderConfig = {
              command     = "argocd-k8s-auth"
              args        = ["gcp"]
              apiVersion  = "client.authentication.k8s.io/v1beta1"
              installHint = "The standard Argo CD image includes argocd-k8s-auth."
            }
            tlsClientConfig = {
              insecure = false
              caData   = var.prod_cluster_ca_certificate
            }
          }
        }
      }
    }

  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  atomic          = true
  cleanup_on_fail = true
  timeout         = 900
  wait            = true
  wait_for_jobs   = true

  values = [yamlencode(local.chart_values)]
}

resource "helm_release" "application" {
  name      = "argocd-stock-ticker"
  namespace = var.namespace
  chart     = "${path.module}/application-chart"

  atomic          = true
  cleanup_on_fail = true
  timeout         = 300
  wait            = true

  values = [
    yamlencode({
      objects = local.extra_objects
    })
  ]

  depends_on = [helm_release.argocd]
}
