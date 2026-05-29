resource "docker_image" "this" {
  name         = var.image_tag
  keep_locally = true
}

resource "docker_container" "this" {
  name  = "tflab-14-${var.name}"
  image = docker_image.this.image_id

  ports {
    internal = 80
    external = var.port
  }

  labels {
    label = "owner"
    value = var.owner
  }

  labels {
    label = "service"
    value = var.name
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    postcondition {
      condition     = length(self.labels) >= 2
      error_message = "Container must have at least 2 labels (owner, service)."
    }
    ignore_changes = [log_opts]
  }
}
