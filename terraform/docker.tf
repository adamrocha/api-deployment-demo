# Docker Image Builds
# These are used by both staging and production

# Generate SSL certificates if needed
resource "null_resource" "ssl_certs" {
  provisioner "local-exec" {
    command     = "./generate-ssl.sh"
    working_dir = "${path.cwd}/../nginx"
  }

  # Only run if certificates don't exist
  triggers = {
    cert_exists = fileexists("${path.cwd}/../nginx/ssl/nginx-selfsigned.crt") ? "exists" : "missing"
  }
}

# Build API Docker Image
resource "docker_image" "api" {
  name = "${var.docker_images.api.name}:${var.docker_images.api.tag}"

  build {
    context    = var.docker_images.api.context
    dockerfile = "Dockerfile"

    tag = [
      "${var.docker_images.api.name}:${var.docker_images.api.tag}",
      "${var.docker_images.api.name}:v1.7"
    ]
  }

  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(var.docker_images.api.context, "**") : filesha1("${var.docker_images.api.context}/${f}")]))
  }
}

# Build Nginx Docker Image
resource "docker_image" "nginx" {
  name = "${var.docker_images.nginx.name}:${var.docker_images.nginx.tag}"

  build {
    context    = var.docker_images.nginx.context
    dockerfile = "Dockerfile"

    tag = ["${var.docker_images.nginx.name}:${var.docker_images.nginx.tag}"]
  }

  triggers = {
    dockerfile_sha = filesha1("${var.docker_images.nginx.context}/Dockerfile")
    nginx_conf_sha = filesha1("${var.docker_images.nginx.context}/nginx.conf")
    html_sha       = filesha1("${var.docker_images.nginx.context}/index.html")
  }

  depends_on = [null_resource.ssl_certs]
}

# Load images to Kind cluster for production
resource "null_resource" "load_images_to_kind" {
  count = var.environment == "production" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      kind load docker-image ${var.docker_images.api.name}:${var.docker_images.api.tag} --name ${var.cluster_name}
      kind load docker-image ${var.docker_images.api.name}:v1.7 --name ${var.cluster_name}
      kind load docker-image ${var.docker_images.nginx.name}:${var.docker_images.nginx.tag} --name ${var.cluster_name}
    EOT
  }

  depends_on = [
    docker_image.api,
    docker_image.nginx
  ]

  triggers = {
    api_image   = docker_image.api.image_id
    nginx_image = docker_image.nginx.image_id
    cluster     = var.cluster_name
  }
}
