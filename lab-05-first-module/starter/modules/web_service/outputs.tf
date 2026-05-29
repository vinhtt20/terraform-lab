# =====================================================================
# Lab 05 — module web_service — TODO: hoàn thiện file này.
# =====================================================================

output "container_id" {
  description = "Docker container ID."
  value       = docker_container.this.id
}

output "name" {
  description = "Container name (matches `docker ps`)."
  value       = docker_container.this.name
}

# Placeholder so the root module references compile. Replace with the
# real URL when you wire external_port through.
output "url" {
  description = "HTTP URL the service is reachable at."
  value       = "http://localhost:${var.external_port}"
}

# TODO O1: thêm output "volume_name" — try(docker_volume.logs[0].name, null).
#   (try() vì khi enable_log_volume = false thì index [0] không tồn tại.)
#   Lưu ý: phải hoàn thành TODO M2 trong main.tf trước để có docker_volume.logs.
