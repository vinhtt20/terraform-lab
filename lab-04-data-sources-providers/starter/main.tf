# =====================================================================
# Lab 04 — TODO: hoàn thiện file này.
#
# Khung dưới valid nhưng:
#   - Thiếu data sources (docker_registry_image, local_file, http).
#   - 2 docker_image chưa pin digest qua data source.
#   - 2 docker_container chưa có provider = docker.east|west,
#     chưa có labels region + motd_sha256.
# =====================================================================

# TODO D1: data "docker_registry_image" "nginx" { name = "nginx:1.27-alpine" }

# TODO D2: data "local_file" "motd" { filename = "${path.module}/files/motd.txt" }

# TODO D3: data "http" "geoip" {
#   count = var.enable_geoip ? 1 : 0
#   url   = "https://ipinfo.io/json"
#   request_timeout_ms = 5000
#   lifecycle {
#     postcondition {
#       condition     = self.status_code == 200
#       error_message = "..."
#     }
#   }
# }

# TODO M1: pin theo digest:
#   name = "${data.docker_registry_image.nginx.name}@${data.docker_registry_image.nginx.sha256_digest}"
# TODO M2: thêm provider = docker.east
resource "docker_image" "east" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# TODO M3: tương tự cho west
resource "docker_image" "west" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# TODO M4: thêm provider = docker.east; thêm 2 labels (region=east, motd_sha256=substr(sha256(...), 0, 16))
resource "docker_container" "east" {
  name  = "tflab-04-east"
  image = docker_image.east.image_id

  ports {
    internal = 80
    external = 8090
  }

  restart = "unless-stopped"
}

# TODO M5: tương tự cho west — provider docker.west, labels region=west.
resource "docker_container" "west" {
  name  = "tflab-04-west"
  image = docker_image.west.image_id

  ports {
    internal = 80
    external = 8091
  }

  restart = "unless-stopped"
}
