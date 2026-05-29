# Generate a random admin password only when the caller did not supply one.
# count = 0 keeps the resource out of state entirely when not needed.
resource "random_password" "admin" {
  count = var.admin_password == null ? 1 : 0

  length  = 20
  special = true
}

# Pin the image by tag. The validation in variables.tf already forbids "latest".
resource "docker_image" "app" {
  name         = "${var.image.name}:${var.image.tag}"
  keep_locally = true
}

# One container per replica. Using for_each over a string-set (not count) keeps
# stable addresses even if replicas changes (e.g. adding replica "3" doesn't
# disturb "0", "1", "2"). See Lab 03 for the count-vs-for_each tradeoff.
resource "docker_container" "app" {
  for_each = toset([for i in range(var.replicas) : tostring(i)])

  name  = "${local.container_name_prefix}-${each.key}"
  image = docker_image.app.image_id

  ports {
    internal = 80
    external = var.external_port_base + tonumber(each.key)
  }

  # Build labels dynamically from local.merged_labels so the map is the single
  # source of truth. Adding a new label means editing one place.
  dynamic "labels" {
    for_each = local.merged_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  restart = "unless-stopped"
}

# Write a config summary that downstream tools can read.
# IMPORTANT: never include the password in this file — it is rendered into a
# plain on-disk file and would defeat the whole sensitive-handling effort.
resource "local_file" "summary" {
  filename = "${path.module}/summary.json"
  content = jsonencode({
    service = var.service_name
    image   = "${var.image.name}:${var.image.tag}"
    names   = [for c in docker_container.app : c.name]
    ports   = [for c in docker_container.app : tolist(c.ports)[0].external]
    labels  = local.merged_labels
  })
}
