locals {
  # Single timestamp captured at plan time, reused everywhere a "created at"
  # field is needed. Output as an output only — gluing it onto a resource
  # attribute would force constant drift on every plan.
  rendered_at = plantimestamp()

  # Build the merged labels map per service so labels = global ∪ service-specific.
  # (Service-specific labels are absent in this lab; this pattern is here so
  # adding a `labels` field to var.services later is a 1-line change.)
  service_labels = {
    for k, _ in var.services :
    k => merge(var.global_labels, { service = k })
  }
}

# One shared nginx image — all services reuse it. Keep_locally so Docker
# doesn't repull on `terraform destroy → apply` cycles.
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# Render a per-service HTML page using templatefile().
# `for_each = var.services` keeps addresses stable: adding a new service does
# NOT shift indices of existing services (a problem we'd have with `count`).
resource "local_file" "html" {
  for_each = var.services

  filename = "${path.module}/html/${each.key}.html"
  content = templatefile("${path.module}/templates/index.html.tftpl", {
    name        = each.key
    port        = each.value.external_port
    env         = each.value.env
    rendered_at = local.rendered_at
  })

  # Avoid plan-time drift from `rendered_at` changing every run.
  lifecycle {
    ignore_changes = [content]
  }
}

# One container per service. Each mounts its own HTML, listens on its own
# host port, and optionally has a healthcheck.
resource "docker_container" "app" {
  for_each = var.services

  name  = "tflab-03-${each.key}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = each.value.external_port
  }

  # `env` is a set(string) attribute: "KEY=VAL" entries. Build it with a
  # for-expression — this is the canonical way to teach the syntax.
  env = [for k, v in each.value.env : "${k}=${v}"]

  # Mount the rendered HTML as the nginx index. abspath() makes the host_path
  # absolute, which Docker requires for bind mounts.
  volumes {
    host_path      = abspath(local_file.html[each.key].filename)
    container_path = "/usr/share/nginx/html/index.html"
    read_only      = true
  }

  # Dynamic healthcheck: present only when the service opts in.
  # for_each = [] on a dynamic block disables it entirely.
  dynamic "healthcheck" {
    for_each = each.value.enable_healthcheck ? [1] : []
    content {
      test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
      interval = "10s"
      timeout  = "3s"
      retries  = 3
    }
  }

  # Labels merged via dynamic block from the precomputed map.
  dynamic "labels" {
    for_each = local.service_labels[each.key]
    content {
      label = labels.key
      value = labels.value
    }
  }

  restart = "unless-stopped"
}
