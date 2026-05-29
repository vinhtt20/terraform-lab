# =====================================================================
# Lab 03 — TODO: hoàn thiện file này.
#
# Cấu trúc khung đã validate, nhưng:
#   - locals.rendered_at chưa dùng plantimestamp().
#   - locals.service_labels chưa được build (cần for-expression + merge).
#   - local_file.html chưa for_each, chưa templatefile().
#   - docker_container.app chưa for_each; chưa mount HTML; chưa env;
#     chưa dynamic "healthcheck"; chưa dynamic "labels".
# =====================================================================

locals {
  # TODO L1: dùng plantimestamp() để chụp 1 thời điểm khi plan.
  rendered_at = "TODO"

  # TODO L2: build map { service_key => merge(global, { service = key }) }
  service_labels = {}
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# TODO M1: for_each = var.services; filename = ${path.module}/html/${each.key}.html
# TODO M2: content = templatefile("${path.module}/templates/index.html.tftpl", { name = ..., port = ..., env = ..., rendered_at = ... })
# TODO M3: lifecycle { ignore_changes = [content] } để rendered_at không gây drift.
resource "local_file" "html" {
  filename = "${path.module}/html/placeholder.html"
  content  = "TODO"
}

# TODO M4: for_each = var.services.
# TODO M5: name = "tflab-03-${each.key}".
# TODO M6: ports.external = each.value.external_port.
# TODO M7: env = [for k, v in each.value.env : "${k}=${v}"].
# TODO M8: volumes { host_path = abspath(local_file.html[each.key].filename), container_path = "/usr/share/nginx/html/index.html", read_only = true }.
# TODO M9: dynamic "healthcheck" { for_each = each.value.enable_healthcheck ? [1] : [] }.
# TODO M10: dynamic "labels" { for_each = local.service_labels[each.key] }.
resource "docker_container" "app" {
  name  = "tflab-03-placeholder"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8083
  }

  restart = "unless-stopped"
}
