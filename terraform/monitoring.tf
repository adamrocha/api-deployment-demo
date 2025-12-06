# Monitoring Stack - Prometheus & Grafana
# Only deployed in production when enable_monitoring = true

resource "kubernetes_namespace" "monitoring" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name = "monitoring"

    labels = {
      name       = "monitoring"
      managed-by = "terraform"
    }
  }
}

# Prometheus Deployment
resource "kubernetes_deployment" "prometheus" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
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
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"

          port {
            container_port = 9090
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
      }
    }
  }
}

# Prometheus Service
resource "kubernetes_service" "prometheus" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
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
resource "kubernetes_deployment" "grafana" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
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
      }
    }
  }
}

# Grafana Service
resource "kubernetes_service" "grafana" {
  count = var.environment == "production" && var.enable_monitoring ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
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
