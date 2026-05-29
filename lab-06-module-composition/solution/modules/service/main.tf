locals {
  # `replica_keys` is the set of identifiers used as for_each keys on the
  # container. Strings — not numbers — so addresses look like
  # docker_container.this["0"], stable even if we later switch to named keys.
  replica_keys = toset([for i in range(var.replicas) : tostring(i)])

  effective_labels = merge(
    { managed_by = "terraform", service = var.name },
    var.labels,
  )
}

# Pull the image. `provider = docker.target` is the explicit way to say
# "use the alias the caller passed in". Without it, the resource would bind
# to the implicit (default) provider — defeating the multi-region design.
resource "docker_image" "this" {
  provider = docker.target

  name         = var.image
  keep_locally = true
}

# One container per replica. for_each over a string-set keeps addresses
# stable: bumping `replicas` from 2 to 3 does NOT disturb replicas 0 and 1.
resource "docker_container" "this" {
  provider = docker.target
  for_each = local.replica_keys

  name  = "tflab-06-${var.name}-${each.key}"
  image = docker_image.this.image_id

  # Attach to the network created by the network module.
  networks_advanced {
    name    = var.network_name
    aliases = [var.name]
  }

  # Each replica gets its own host port: base + idx. Without this offset,
  # multiple replicas of the same service would collide on the host.
  ports {
    internal = 80
    external = var.external_port + tonumber(each.key)
  }

  # Conditional healthcheck. for_each = [] disables the block entirely.
  dynamic "healthcheck" {
    for_each = var.healthcheck.enabled ? [1] : []
    content {
      test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
      interval = var.healthcheck.interval
      timeout  = "3s"
      retries  = 3
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
