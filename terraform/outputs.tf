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
    web        = "http://localhost:80 (redirects to HTTPS)"
    web_https  = "https://localhost:443"
    api        = "http://localhost:8000/health"
    api_docs   = "http://localhost:8000/docs"
    api_via_nginx = "https://localhost:443/api/health"
    grafana    = var.enable_monitoring ? "http://localhost:3000" : null
    prometheus = var.enable_monitoring ? "http://localhost:9090" : null
  } : null
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.environment == "production" ? var.cluster_name : null
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.environment == "production" ? kubernetes_namespace.app[0].metadata[0].name : null
}

output "docker_images" {
  description = "Built Docker images"
  value = {
    api   = docker_image.api.name
    nginx = docker_image.nginx.name
  }
}
