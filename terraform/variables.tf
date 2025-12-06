variable "project_name" {
  description = "Project name"
  type        = string
  default     = "api-deployment-demo"
}

variable "environment" {
  description = "Environment (staging or production)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

variable "cluster_name" {
  description = "Kind cluster name for production"
  type        = string
  default     = "api-demo-cluster"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "staging_password"
}

variable "secret_key" {
  description = "API secret key"
  type        = string
  sensitive   = true
  default     = "change-me-in-production"
}

variable "staging_ports" {
  description = "Port mappings for staging environment"
  type = object({
    http  = number
    https = number
    api   = number
    db    = number
  })
  default = {
    http  = 30080
    https = 30443
    api   = 30800
    db    = 35432
  }
}

variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus/Grafana)"
  type        = bool
  default     = true
}

variable "docker_images" {
  description = "Docker image configurations"
  type = map(object({
    name    = string
    context = string
    tag     = string
  }))
  default = {
    api = {
      name    = "api-deployment-demo-api"
      context = "../api"
      tag     = "latest"
    }
    nginx = {
      name    = "api-deployment-demo-nginx"
      context = "../nginx"
      tag     = "latest"
    }
  }
}

variable "replicas" {
  description = "Number of replicas for production deployment"
  type        = number
  default     = 2
}
