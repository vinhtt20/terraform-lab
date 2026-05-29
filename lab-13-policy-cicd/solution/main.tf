resource "docker_image" "app" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "tflab-13-${var.owner}"
  image = docker_image.app.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  labels {
    label = "owner"
    value = var.owner
  }

  labels {
    label = "tflab.lab"
    value = "13"
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}
