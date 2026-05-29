locals {
  cfg = lookup(var.workspace_config, terraform.workspace, var.workspace_config["default"])
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  count = local.cfg.replicas

  name  = "tflab-10-${terraform.workspace}-${count.index + 1}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = local.cfg.port + count.index
  }

  labels {
    label = "tflab.workspace"
    value = terraform.workspace
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}
