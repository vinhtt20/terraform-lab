# =====================================================================
# Lab 06 — STARTER: đây là MONOLITH cần được refactor thành 2 modules.
#
# Mục tiêu: refactor file này sao cho:
#   1. Network được tạo bởi module "./modules/network".
#   2. 3 service (web/api/worker) được dựng bởi module "./modules/service",
#      gọi 2 lần — module "service_east" và module "service_west" — vì
#      mỗi service được deploy vào 1 region khác nhau qua provider alias.
#
# Sau khi refactor:
#   - File monolith này biến thành ngắn (~50 dòng): chỉ locals + 3 module call.
#   - Không còn docker_network / docker_container / docker_image ở root.
#
# Đọc README "Yêu cầu cụ thể" + HINTS để biết cấu trúc module.
# =====================================================================

resource "docker_network" "platform" {
  name   = "tflab-06-net"
  driver = "bridge"

  labels {
    label = "managed_by"
    value = "terraform"
  }
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# Service: web — 2 replicas, port 8100-8101.
resource "docker_container" "web" {
  for_each = toset(["0", "1"])

  name  = "tflab-06-web-${each.key}"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.platform.name
    aliases = ["web"]
  }

  ports {
    internal = 80
    external = 8100 + tonumber(each.key)
  }

  healthcheck {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }

  labels {
    label = "managed_by"
    value = "terraform"
  }
  labels {
    label = "service"
    value = "web"
  }
  labels {
    label = "region"
    value = "east"
  }

  restart = "unless-stopped"
}

# Service: api — 1 replica, port 8102.
resource "docker_container" "api" {
  name  = "tflab-06-api-0"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.platform.name
    aliases = ["api"]
  }

  ports {
    internal = 80
    external = 8102
  }

  healthcheck {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }

  labels {
    label = "managed_by"
    value = "terraform"
  }
  labels {
    label = "service"
    value = "api"
  }
  labels {
    label = "region"
    value = "west"
  }

  restart = "unless-stopped"
}

# Service: worker — 1 replica, port 8103.
resource "docker_container" "worker" {
  name  = "tflab-06-worker-0"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.platform.name
    aliases = ["worker"]
  }

  ports {
    internal = 80
    external = 8103
  }

  healthcheck {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }

  labels {
    label = "managed_by"
    value = "terraform"
  }
  labels {
    label = "service"
    value = "worker"
  }
  labels {
    label = "region"
    value = "east"
  }

  restart = "unless-stopped"
}
