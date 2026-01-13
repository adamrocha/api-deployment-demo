output "environment" {
  description = "Deployed environment"
  value       = var.environment
}

output "staging_urls" {
  description = "Staging environment access URLs"
  value = var.environment == "staging" ? {
    web_https = "https://localhost:${var.staging_ports.https}"
    api       = "http://localhost:${var.staging_ports.api}/health"
    api_docs  = "http://localhost:${var.staging_ports.api}/docs"
    database  = "localhost:${var.staging_ports.db}"
  } : null
}

output "production_urls" {
  description = "Production environment access URLs"
  value = var.environment == "production" ? {
    web           = "http://localhost:80 (redirects to HTTPS)"
    web_https     = "https://localhost:443"
    api           = "http://localhost:8000/health"
    api_docs      = "http://localhost:8000/docs"
    api_via_nginx = "https://localhost:443/api/health"
    grafana       = var.enable_monitoring ? "http://localhost:3000" : null
    prometheus    = var.enable_monitoring ? "http://localhost:9090" : null
  } : null
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.environment == "production" ? var.cluster_name : null
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.environment == "production" ? kubernetes_namespace_v1.app[0].metadata[0].name : null
}

output "docker_images" {
  description = "Built Docker images"
  value = {
    api   = docker_image.api.name
    nginx = docker_image.nginx.name
  }
}

output "autoscaling_config" {
  description = "HPA autoscaling configuration"
  value = var.environment == "production" ? {
    enabled               = true
    min_replicas          = 2
    max_replicas          = 10
    cpu_threshold_percent = 50
    scale_up_policy       = "100% or 4 pods per 15 seconds"
    scale_down_policy     = "50% per 60 seconds after 5 min stabilization"
    stress_endpoint_info  = "/stress calculates 75,000 primes for CPU load testing"
  } : null
}

output "health_check_config" {
  description = "Pod health check configuration"
  value = var.environment == "production" ? {
    startup_initial_delay       = "10s"
    startup_timeout             = "5s"
    startup_period              = "10s"
    startup_failure_threshold   = 12
    startup_max_time            = "120s (12 x 10s)"
    liveness_period             = "30s"
    liveness_timeout            = "10s"
    liveness_failure_threshold  = 6
    liveness_max_grace          = "180s (6 x 30s) before restart"
    readiness_period            = "10s"
    readiness_timeout           = "10s"
    readiness_failure_threshold = 3
    readiness_max_grace         = "30s (3 x 10s) before traffic removal"
  } : null
}
