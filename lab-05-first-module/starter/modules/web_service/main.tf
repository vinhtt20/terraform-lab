# =====================================================================
# Lab 05 — module web_service — TODO: hoàn thiện file này.
#
# Khung dưới validate được nhưng:
#   - Thiếu locals (container_name, effective_labels).
#   - Thiếu local_file.index conditional (chỉ tạo khi index_content != null).
#   - Thiếu docker_volume.logs conditional (chỉ tạo khi enable_log_volume).
#   - docker_container.this chưa dynamic "volumes" cho 2 trường hợp trên.
#   - docker_container.this chưa dynamic "labels" từ effective_labels.
# =====================================================================

locals {
  container_name = "tflab-05-${var.name}"

  # TODO L1: effective_labels = merge(
  #   { managed_by = "terraform", service = var.name },
  #   var.labels,
  # )
  effective_labels = var.labels
}

resource "docker_image" "this" {
  name         = var.image
  keep_locally = true
}

# TODO M1: thêm resource "local_file" "index" {
#   count    = var.index_content == null ? 0 : 1
#   filename = "${path.module}/rendered/${var.name}.html"
#   content  = var.index_content
# }

# TODO M2: thêm resource "docker_volume" "logs" {
#   count = var.enable_log_volume ? 1 : 0
#   name  = "${local.container_name}-logs"
# }

resource "docker_container" "this" {
  name  = local.container_name
  image = docker_image.this.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  # TODO M3: dynamic "volumes" mount local_file.index[0] vào /usr/share/nginx/html/index.html
  #   for_each = var.index_content == null ? [] : [1]
  #   content { host_path = abspath(local_file.index[0].filename), container_path = "/usr/share/nginx/html/index.html", read_only = true }

  # TODO M4: dynamic "volumes" mount docker_volume.logs[0] vào /var/log/nginx
  #   for_each = var.enable_log_volume ? [1] : []
  #   content { volume_name = docker_volume.logs[0].name, container_path = "/var/log/nginx" }

  # TODO M5: dynamic "labels" lặp qua local.effective_labels.
  labels {
    label = "managed_by"
    value = "terraform"
  }

  restart = "unless-stopped"
}
