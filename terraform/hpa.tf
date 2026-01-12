# Horizontal Pod Autoscaler for API Deployment
# Automatically scales API pods based on CPU utilization

resource "kubernetes_horizontal_pod_autoscaler_v2" "api_deployment" {
  count = var.environment == "production" ? 1 : 0

  metadata {
    name      = "api-deployment"
    namespace = kubernetes_namespace_v1.app[0].metadata[0].name

    labels = {
      app         = "api-demo"
      component   = "api"
      managed-by  = "terraform"
      environment = var.environment
    }
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "api-deployment"
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0
        select_policy                = "Max"

        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 15
        }

        policy {
          type           = "Pods"
          value          = 4
          period_seconds = 15
        }
      }

      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Min"

        policy {
          type           = "Percent"
          value          = 50
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.api,
    kubernetes_deployment_v1.metrics_server
  ]
}
