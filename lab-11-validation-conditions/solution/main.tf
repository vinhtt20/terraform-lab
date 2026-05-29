resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true

  lifecycle {
    postcondition {
      condition     = self.image_id != ""
      error_message = "Image must have a resolved image_id after pull."
    }
  }
}

resource "docker_container" "app" {
  count = var.replicas

  name  = "${var.name_prefix}-${count.index + 1}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.base_port + count.index
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    precondition {
      condition     = (var.base_port + count.index) < 10000
      error_message = "Port (base_port + count.index) must remain under 10000."
    }
    postcondition {
      condition     = length(self.ports) > 0 && self.ports[0].external == (var.base_port + count.index)
      error_message = "Container did not bind the expected external port."
    }
    ignore_changes = [log_opts]
  }
}

check "unique_ports" {
  assert {
    condition     = length(distinct([for c in docker_container.app : c.ports[0].external])) == length(docker_container.app)
    error_message = "External ports of containers must be unique."
  }
}
