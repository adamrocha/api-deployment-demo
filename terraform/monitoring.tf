# Monitoring Stack - Prometheus & Grafana
# Only deployed in production when enable_monitoring = true

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name = "monitoring"

    labels = {
      name       = "monitoring"
      managed-by = "terraform"
    }
  }
}

# Prometheus ConfigMap
resource "kubernetes_config_map_v1" "prometheus_config" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 15s
        evaluation_interval: 15s

      scrape_configs:
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']

        - job_name: 'api'
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names:
                  - api-deployment-demo
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app]
              regex: api-demo
              action: keep
            - source_labels: [__meta_kubernetes_pod_label_component]
              regex: api
              action: keep
            - source_labels: [__meta_kubernetes_pod_ip]
              regex: (.+)
              target_label: __address__
              replacement: $${1}:8000
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod
            - source_labels: [__meta_kubernetes_namespace]
              target_label: namespace

        - job_name: 'postgres-exporter'
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names:
                  - api-deployment-demo
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app]
              regex: postgres
              action: keep
            - source_labels: [__meta_kubernetes_pod_ip]
              regex: (.+)
              target_label: __address__
              replacement: $${1}:9187
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod
            - source_labels: [__meta_kubernetes_namespace]
              target_label: namespace

        - job_name: 'nginx-exporter'
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names:
                  - api-deployment-demo
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app]
              regex: api-demo
              action: keep
            - source_labels: [__meta_kubernetes_pod_label_component]
              regex: nginx
              action: keep
            - source_labels: [__meta_kubernetes_pod_ip]
              regex: (.+)
              target_label: __address__
              replacement: $${1}:9113
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod
            - source_labels: [__meta_kubernetes_namespace]
              target_label: namespace

        - job_name: 'kube-state-metrics'
          static_configs:
            - targets: ['kube-state-metrics.monitoring.svc.cluster.local:8080']
    EOT
  }
}

# Prometheus Deployment
resource "kubernetes_deployment_v1" "prometheus" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.prometheus[0].metadata[0].name

        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles"
          ]

          port {
            container_port = 9090
          }

          volume_mount {
            name       = "prometheus-config"
            mount_path = "/etc/prometheus"
          }

          volume_mount {
            name       = "prometheus-storage"
            mount_path = "/prometheus"
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        volume {
          name = "prometheus-config"
          config_map {
            name = "prometheus-config"
          }
        }

        volume {
          name = "prometheus-storage"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [kubernetes_config_map_v1.prometheus_config]
}

# Prometheus ServiceAccount
resource "kubernetes_service_account_v1" "prometheus" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }
}

# Prometheus ClusterRole
resource "kubernetes_cluster_role_v1" "prometheus" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name = "prometheus"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get"]
  }
}

# Prometheus ClusterRoleBinding
resource "kubernetes_cluster_role_binding_v1" "prometheus" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name = "prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.prometheus[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.prometheus[0].metadata[0].name
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }
}

# Prometheus Service
resource "kubernetes_service_v1" "prometheus" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
      node_port   = 30900
    }

    type = "NodePort"
  }

  timeouts {
    create = "3m"
  }
}

# Grafana Deployment
resource "kubernetes_deployment_v1" "grafana" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:latest"

          port {
            container_port = 3000
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "admin"
          }

          env {
            name  = "GF_PATHS_PROVISIONING"
            value = "/etc/grafana/provisioning"
          }

          volume_mount {
            name       = "dashboards-provisioning"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }

          volume_mount {
            name       = "dashboard-api-performance"
            mount_path = "/var/lib/grafana/dashboards/api-performance.json"
            sub_path   = "api-performance.json"
          }

          volume_mount {
            name       = "dashboard-infrastructure"
            mount_path = "/var/lib/grafana/dashboards/infrastructure.json"
            sub_path   = "infrastructure.json"
          }

          volume_mount {
            name       = "dashboard-database"
            mount_path = "/var/lib/grafana/dashboards/database.json"
            sub_path   = "database.json"
          }

          volume_mount {
            name       = "dashboard-nginx-traffic"
            mount_path = "/var/lib/grafana/dashboards/nginx-traffic.json"
            sub_path   = "nginx-traffic.json"
          }

          volume_mount {
            name       = "datasource-provisioning"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "250m"
            }
          }
        }

        volume {
          name = "dashboards-provisioning"
          config_map {
            name = "grafana-dashboards-provisioning"
          }
        }

        volume {
          name = "dashboard-api-performance"
          config_map {
            name = "grafana-dashboard-api-performance"
          }
        }

        volume {
          name = "dashboard-infrastructure"
          config_map {
            name = "grafana-dashboard-infrastructure"
          }
        }

        volume {
          name = "dashboard-database"
          config_map {
            name = "grafana-dashboard-database"
          }
        }

        volume {
          name = "dashboard-nginx-traffic"
          config_map {
            name = "grafana-dashboard-nginx-traffic"
          }
        }

        volume {
          name = "datasource-provisioning"
          config_map {
            name = "grafana-datasource-provisioning"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map_v1.grafana_dashboards_provisioning,
    kubernetes_config_map_v1.grafana_dashboard_api_performance,
    kubernetes_config_map_v1.grafana_dashboard_infrastructure,
    kubernetes_config_map_v1.grafana_dashboard_database,
    kubernetes_config_map_v1.grafana_dashboard_nginx_traffic,
    kubernetes_config_map_v1.grafana_datasource_provisioning
  ]
}

# Grafana Service
resource "kubernetes_service_v1" "grafana" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      node_port   = 30300
    }

    type = "NodePort"
  }

  timeouts {
    create = "3m"
  }
}

# Grafana Dashboard Provisioning ConfigMap
resource "kubernetes_config_map_v1" "grafana_dashboards_provisioning" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana-dashboards-provisioning"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  data = {
    "dashboards.yaml" = <<-EOT
      apiVersion: 1
      providers:
        - name: 'API Demo Dashboards'
          orgId: 1
          folder: 'API Demo'
          type: file
          disableDeletion: false
          updateIntervalSeconds: 10
          allowUiUpdates: true
          options:
            path: /var/lib/grafana/dashboards
    EOT
  }
}

# Grafana Dashboard ConfigMaps
resource "kubernetes_config_map_v1" "grafana_dashboard_api_performance" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana-dashboard-api-performance"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "api-performance.json" = file("${path.module}/../monitoring/dashboards/api-performance.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard_infrastructure" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana-dashboard-infrastructure"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "infrastructure.json" = file("${path.module}/../monitoring/dashboards/infrastructure.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard_database" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana-dashboard-database"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "database.json" = file("${path.module}/../monitoring/dashboards/database.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard_nginx_traffic" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana-dashboard-nginx-traffic"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "nginx-traffic.json" = file("${path.module}/../monitoring/dashboards/nginx-traffic.json")
  }
}

# Prometheus Data Source Provisioning
resource "kubernetes_config_map_v1" "grafana_datasource_provisioning" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana-datasource-provisioning"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  data = {
    "datasource.yaml" = <<-EOT
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          access: proxy
          url: http://prometheus:9090
          isDefault: true
          editable: true
    EOT
  }
}

# ============================================================================
# kube-state-metrics - Automated Deployment
# ============================================================================

# ServiceAccount for kube-state-metrics
resource "kubernetes_service_account_v1" "kube_state_metrics" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }
}

# ClusterRole for kube-state-metrics
resource "kubernetes_cluster_role_v1" "kube_state_metrics" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name = "kube-state-metrics"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets", "nodes", "pods", "services", "resourcequotas", "replicationcontrollers", "limitranges", "persistentvolumeclaims", "persistentvolumes", "namespaces", "endpoints"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "daemonsets", "deployments", "replicasets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses", "volumeattachments"]
    verbs      = ["list", "watch"]
  }
}

# ClusterRoleBinding for kube-state-metrics
resource "kubernetes_cluster_role_binding_v1" "kube_state_metrics" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name = "kube-state-metrics"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.kube_state_metrics[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.kube_state_metrics[0].metadata[0].name
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }
}

# kube-state-metrics Deployment
resource "kubernetes_deployment_v1" "kube_state_metrics" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name

    labels = {
      app       = "kube-state-metrics"
      component = "exporter"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kube-state-metrics"
      }
    }

    template {
      metadata {
        labels = {
          app       = "kube-state-metrics"
          component = "exporter"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.kube_state_metrics[0].metadata[0].name

        container {
          name  = "kube-state-metrics"
          image = "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.1"

          port {
            name           = "http-metrics"
            container_port = 8080
          }

          port {
            name           = "telemetry"
            container_port = 8081
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

# kube-state-metrics Service
resource "kubernetes_service_v1" "kube_state_metrics" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name

    labels = {
      app       = "kube-state-metrics"
      component = "exporter"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "kube-state-metrics"
    }

    port {
      name        = "http-metrics"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    port {
      name        = "telemetry"
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
    }
  }
}
