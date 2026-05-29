# =====================================================================
# Lab 08 — SOLUTION: 6 pre-existing Docker resources imported via
# `import {}` blocks + cleaned-up config.
#
# The pre-existing stack created by setup.sh:
#   - docker network: tflab-08-net
#   - docker volumes: tflab-08-data1, tflab-08-data2
#   - docker containers: tflab-08-app1 (port 8111, mount data1),
#                        tflab-08-app2 (port 8112, mount data2),
#                        tflab-08-app3 (port 8113, no volume)
#
# After running `terraform plan -generate-config-out=generated.tf`,
# Terraform emitted a flat resource block per imported object — one
# verbose block per container. The version below is the RESULT of
# refactoring that draft into idiomatic style:
#   - single docker_image resource (DRY)
#   - docker_volume.this with for_each over a string set
#   - docker_container.app with for_each over a map of structured config
# =====================================================================

locals {
  # Single source of truth for the 3 imported apps. Adding a 4th app later
  # is one line here + one import block in imports.tf.
  apps = {
    app1 = {
      port   = 8111
      volume = "data1"
    }
    app2 = {
      port   = 8112
      volume = "data2"
    }
    app3 = {
      port   = 8113
      volume = null # no mounted volume — dynamic block will skip it
    }
  }

  volumes = toset(["data1", "data2"])
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_network" "main" {
  name   = "tflab-08-net"
  driver = "bridge"
}

resource "docker_volume" "this" {
  for_each = local.volumes
  name     = "tflab-08-${each.key}"
}

resource "docker_container" "app" {
  for_each = local.apps

  name  = "tflab-08-${each.key}"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.main.name
  }

  ports {
    internal = 80
    external = each.value.port
  }

  # Only mount when this app has an associated volume.
  dynamic "volumes" {
    for_each = each.value.volume == null ? [] : [each.value.volume]
    content {
      volume_name    = docker_volume.this[volumes.value].name
      container_path = "/var/data"
    }
  }

  restart      = "unless-stopped"
  must_run     = true
  network_mode = "default"
  log_driver   = "json-file"
}
