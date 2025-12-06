# Production Environment - Kubernetes (Kind)
# Only created when environment = "production"

# Kubernetes Namespace
resource "kubernetes_namespace" "app" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name = var.project_name

    labels = {
      environment = "production"
      managed-by  = "terraform"
    }
  }
}

# Kubernetes Secret for Database
resource "kubernetes_secret" "database" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "database-credentials"
    namespace = kubernetes_namespace.app[0].metadata[0].name
  }

  data = {
    db-name     = "api_db"
    db-user     = "postgres"
    db-password = var.db_password
  }

  type = "Opaque"
}

# Kubernetes Secret for API
resource "kubernetes_secret" "api" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "api-secrets"
    namespace = kubernetes_namespace.app[0].metadata[0].name
  }

  data = {
    secret-key = var.secret_key
  }

  type = "Opaque"
}

# PostgreSQL Deployment
resource "kubernetes_deployment" "postgres" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.app[0].metadata[0].name

    labels = {
      app = "postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database[0].metadata[0].name
                key  = "db-name"
              }
            }
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database[0].metadata[0].name
                key  = "db-user"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database[0].metadata[0].name
                key  = "db-password"
              }
            }
          }

          port {
            container_port = 5432
            name           = "postgres"
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

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }
      }
    }
  }
}

# PostgreSQL Service
resource "kubernetes_service" "postgres" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.app[0].metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }

  timeouts {
    create = "3m"
  }

  depends_on = [kubernetes_deployment.postgres]
}

# API Deployment
resource "kubernetes_deployment" "api" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "api-deployment"
    namespace = kubernetes_namespace.app[0].metadata[0].name

    labels = {
      app = "api-demo"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "api-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "api-demo"
        }
      }

      spec {
        container {
          name              = "api"
          image             = "${var.docker_images.api.name}:${var.docker_images.api.tag}"
          image_pull_policy = "Never"

          env {
            name  = "DB_USER"
            value = "postgres"
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database[0].metadata[0].name
                key  = "db-password"
              }
            }
          }

          env {
            name  = "DB_HOST"
            value = "postgres"
          }

          env {
            name  = "DB_PORT"
            value = "5432"
          }

          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database[0].metadata[0].name
                key  = "db-name"
              }
            }
          }

          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.api[0].metadata[0].name
                key  = "secret-key"
              }
            }
          }

          env {
            name  = "API_ENV"
            value = "production"
          }

          port {
            container_port = 8000
            name           = "http"
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

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 60
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 30
            period_seconds        = 5
          }
        }
      }
    }
  }

  timeouts {
    create = "10m"
    update = "10m"
  }

  depends_on = [kubernetes_deployment.postgres]
}

# API Service
resource "kubernetes_service" "api" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "api-service"
    namespace = kubernetes_namespace.app[0].metadata[0].name
  }

  spec {
    selector = {
      app = "api-demo"
    }

    port {
      port        = 8000
      target_port = 8000
      node_port   = 30800
    }

    type = "NodePort"
  }

  timeouts {
    create = "3m"
  }
}

# API Service Alias (for Nginx compatibility)
# Nginx config expects to resolve "api:8000"
resource "kubernetes_service" "api_alias" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "api"
    namespace = kubernetes_namespace.app[0].metadata[0].name
  }

  spec {
    selector = {
      app = "api-demo"
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }

  timeouts {
    create = "3m"
  }
}

# Apply Kubernetes ConfigMaps from manifests
resource "null_resource" "apply_configmaps" {
  count = var.environment == "production" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/../kubernetes/configmaps.yaml --validate=false
      kubectl apply -f ${path.module}/../kubernetes/nginx-html-configmap.yaml --validate=false
      kubectl apply -f ${path.module}/../kubernetes/tls-secret.yaml --validate=false
    EOT
  }

  depends_on = [kubernetes_namespace.app]

  triggers = {
    configmaps_hash = filesha1("${path.module}/../kubernetes/configmaps.yaml")
    html_hash       = filesha1("${path.module}/../kubernetes/nginx-html-configmap.yaml")
    tls_hash        = filesha1("${path.module}/../kubernetes/tls-secret.yaml")
  }
}

# Nginx Deployment (Enhanced to match Make method)
resource "kubernetes_deployment" "nginx" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.app[0].metadata[0].name
    labels = {
      app       = "api-demo"
      component = "nginx"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app       = "api-demo"
        component = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app       = "api-demo"
          component = "nginx"
        }
      }

      spec {
        security_context {
          run_as_non_root = false
          fs_group        = 101
        }

        container {
          name              = "nginx"
          image             = "${var.docker_images.nginx.name}:${var.docker_images.nginx.tag}"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 80
            name           = "http"
          }

          port {
            container_port = 443
            name           = "https"
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
            read_only  = true
          }

          volume_mount {
            name       = "ssl-certs"
            mount_path = "/etc/nginx/ssl"
            read_only  = true
          }

          volume_mount {
            name       = "nginx-html"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "200m"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            run_as_user                = 0
            capabilities {
              drop = ["NET_RAW"]
              add  = ["CHOWN", "SETUID", "SETGID", "DAC_OVERRIDE", "FOWNER", "NET_BIND_SERVICE"]
            }
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = "nginx-config"
            items {
              key  = "nginx.conf"
              path = "default.conf"
            }
          }
        }

        volume {
          name = "ssl-certs"
          secret {
            secret_name = "nginx-ssl-certs"
            optional    = true
          }
        }

        volume {
          name = "nginx-html"
          config_map {
            name = "nginx-html"
          }
        }
      }
    }
  }

  timeouts {
    create = "10m"
    update = "10m"
  }

  depends_on = [kubernetes_deployment.api, null_resource.ssl_certs, null_resource.apply_configmaps]
}

# Nginx Service (LoadBalancer type to match Make method)
resource "kubernetes_service" "nginx" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.app[0].metadata[0].name
    labels = {
      app       = "api-demo"
      component = "nginx"
    }
  }

  spec {
    selector = {
      app       = "api-demo"
      component = "nginx"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      node_port   = 30080
      protocol    = "TCP"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 443
      node_port   = 30443
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  timeouts {
    create = "5m"
  }

  # Don't wait for LoadBalancer external IP in Kind cluster
  wait_for_load_balancer = false

  depends_on = [kubernetes_deployment.nginx]
}
