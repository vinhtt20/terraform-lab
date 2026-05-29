resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# Managed no-op sentinel. terraform_data.rotation.output mirrors input.
# When var.rotation_id changes, this resource's `output` attribute changes,
# which fires replace_triggered_by on the container below.
resource "terraform_data" "rotation" {
  input = var.rotation_id
}

resource "docker_container" "app" {
  name  = "tflab-12-app"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    # Watch the rotation sentinel. Any change → replace container.
    # Use the resource address (not an attribute) so any field change fires.
    replace_triggered_by = [terraform_data.rotation]

    ignore_changes = [log_opts]
  }
}
