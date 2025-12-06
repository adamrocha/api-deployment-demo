# Staging Environment - Docker Compose
# Only created when environment = "staging"

# Docker Network
resource "docker_network" "staging" {
  count = var.environment == "staging" ? 1 : 0

  name   = "${var.project_name}_staging_network"
  driver = "bridge"
}

# Docker Volume for PostgreSQL
resource "docker_volume" "postgres_data" {
  count = var.environment == "staging" ? 1 : 0

  name = "${var.project_name}_staging_postgres_data"
}

# PostgreSQL Container
resource "docker_container" "postgres" {
  count = var.environment == "staging" ? 1 : 0

  name  = "api_postgres_staging"
  image = "postgres:15-alpine"

  networks_advanced {
    name    = docker_network.staging[0].name
    aliases = ["postgres"]
  }

  env = [
    "POSTGRES_DB=api_staging",
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_HOST_AUTH_METHOD=md5"
  ]

  volumes {
    volume_name    = docker_volume.postgres_data[0].name
    container_path = "/var/lib/postgresql/data"
  }

  volumes {
    host_path      = "${path.cwd}/../database/init.sql"
    container_path = "/docker-entrypoint-initdb.d/init.sql"
    read_only      = true
  }

  ports {
    internal = 5432
    external = var.staging_ports.db
  }

  restart = "unless-stopped"

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U postgres -d api_staging"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "30s"
  }
}

# API Container
resource "docker_container" "api" {
  count = var.environment == "staging" ? 1 : 0

  name  = "api_python_staging"
  image = docker_image.api.image_id

  networks_advanced {
    name    = docker_network.staging[0].name
    aliases = ["api"]
  }

  env = [
    "DATABASE_URL=postgresql://postgres:${var.db_password}@postgres:5432/api_staging",
    "API_ENV=staging",
    "DEBUG=false",
    "SECRET_KEY=${var.secret_key}",
    "API_WORKERS=4",
    "LOG_LEVEL=info",
    "API_PORT=8000"
  ]

  ports {
    internal = 8000
    external = var.staging_ports.api
  }

  restart = "unless-stopped"

  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "60s"
  }

  depends_on = [docker_container.postgres]
}

# Nginx Container
resource "docker_container" "nginx" {
  count = var.environment == "staging" ? 1 : 0

  name  = "api_nginx_staging"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.staging[0].name
    aliases = ["nginx"]
  }

  env = [
    "API_UPSTREAM=api:8000",
    "SERVER_NAME=localhost",
    "SSL_ENABLED=true",
    "HTTP_PORT=80",
    "HTTPS_PORT=443"
  ]

  volumes {
    host_path      = "${path.cwd}/../nginx/logs"
    container_path = "/var/log/nginx"
  }

  volumes {
    host_path      = "${path.cwd}/../nginx/ssl"
    container_path = "/etc/nginx/ssl"
    read_only      = true
  }

  volumes {
    host_path      = "${path.cwd}/../nginx/index.html"
    container_path = "/usr/share/nginx/html/index.html"
    read_only      = true
  }

  ports {
    internal = 80
    external = var.staging_ports.http
  }

  ports {
    internal = 443
    external = var.staging_ports.https
  }

  restart = "unless-stopped"

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost/health"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }

  depends_on = [docker_container.api]
}
