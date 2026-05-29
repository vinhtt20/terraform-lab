###############################################################################
# Data sources — read-only views into existing state of the world.
###############################################################################

# Fetch the current digest of the upstream nginx tag so we can pin images by
# sha256 instead of by mutable tag. This data source talks to the Docker
# registry — it runs at plan/refresh time, NOT only at apply.
data "docker_registry_image" "nginx" {
  name = "nginx:1.27-alpine"
}

# Read a file shipped with the module. Useful when the value belongs in source
# control (e.g. a banner, a cert, a public key) rather than in tfvars.
data "local_file" "motd" {
  filename = "${path.module}/files/motd.txt"
}

# Optional external call — disabled by default to keep CI offline.
# Note the `count` trick: data sources can be conditionalized just like resources.
data "http" "geoip" {
  count = var.enable_geoip ? 1 : 0

  url                = "https://ipinfo.io/json"
  request_timeout_ms = 5000

  # Demo of a postcondition on a data source: fail the plan if status != 200.
  # See Lab 11 for the full story on conditions.
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Expected HTTP 200 from ipinfo.io, got ${self.status_code}."
    }
  }
}

###############################################################################
# Resources — managed by Terraform. Note the `provider =` meta-argument.
###############################################################################

# East "region" image — pinned by digest. We compose "<repo:tag>@<sha256:...>"
# from the data source so the image actually gets pulled by digest. Pulling
# by the tag alone would defeat the whole point of looking the digest up.
resource "docker_image" "east" {
  provider = docker.east

  name         = "${data.docker_registry_image.nginx.name}@${data.docker_registry_image.nginx.sha256_digest}"
  keep_locally = true
}

resource "docker_image" "west" {
  provider = docker.west

  name         = "${data.docker_registry_image.nginx.name}@${data.docker_registry_image.nginx.sha256_digest}"
  keep_locally = true
}

resource "docker_container" "east" {
  provider = docker.east

  name  = "tflab-04-east"
  image = docker_image.east.image_id

  ports {
    internal = 80
    external = 8090
  }

  labels {
    label = "region"
    value = "east"
  }
  labels {
    # First 16 hex chars of the motd hash — enough to identify the file
    # without bloating the docker label table.
    label = "motd_sha256"
    value = substr(sha256(data.local_file.motd.content), 0, 16)
  }

  restart = "unless-stopped"
}

resource "docker_container" "west" {
  provider = docker.west

  name  = "tflab-04-west"
  image = docker_image.west.image_id

  ports {
    internal = 80
    external = 8091
  }

  labels {
    label = "region"
    value = "west"
  }
  labels {
    label = "motd_sha256"
    value = substr(sha256(data.local_file.motd.content), 0, 16)
  }

  restart = "unless-stopped"
}
