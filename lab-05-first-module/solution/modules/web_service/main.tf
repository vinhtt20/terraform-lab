locals {
  # Single source of truth for the container name. Every output and every
  # cross-resource reference derives from this so a rename only touches one
  # line.
  container_name = "tflab-05-${var.name}"

  # Always tag the resource so a human (or operator running `docker ps`) can
  # see who owns it. Caller-provided labels override these defaults.
  effective_labels = merge(
    { managed_by = "terraform", service = var.name },
    var.labels,
  )
}

# Pull the image. Keeping it locally avoids re-pulling on every
# destroy/apply cycle in the lab.
resource "docker_image" "this" {
  name         = var.image
  keep_locally = true
}

# Optional: render a custom index.html. Using `count` here is the canonical
# toggle pattern — the resource simply does not exist when not requested.
# We can't use a single resource with `null`/empty content because the
# caller may want the image's default index untouched.
resource "local_file" "index" {
  count = var.index_content == null ? 0 : 1

  filename = "${path.module}/rendered/${var.name}.html"
  content  = var.index_content
}

# Optional: a named volume for /var/log/nginx. Like local_file.index, this
# is gated on a boolean so the resource is fully absent when not needed.
resource "docker_volume" "logs" {
  count = var.enable_log_volume ? 1 : 0

  name = "${local.container_name}-logs"
}

resource "docker_container" "this" {
  name  = local.container_name
  image = docker_image.this.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  # Bind-mount the rendered index when present. abspath() is required:
  # Docker rejects relative host_path values.
  dynamic "volumes" {
    for_each = var.index_content == null ? [] : [1]
    content {
      host_path      = abspath(local_file.index[0].filename)
      container_path = "/usr/share/nginx/html/index.html"
      read_only      = true
    }
  }

  # Named-volume mount for logs, when enabled. Use volume_name + container_path
  # (NOT host_path) so Docker manages the volume's lifecycle.
  dynamic "volumes" {
    for_each = var.enable_log_volume ? [1] : []
    content {
      volume_name    = docker_volume.logs[0].name
      container_path = "/var/log/nginx"
    }
  }

  dynamic "labels" {
    for_each = local.effective_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  restart = "unless-stopped"
}
