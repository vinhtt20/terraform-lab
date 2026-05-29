output "container_id" {
  description = "Docker container ID (full SHA). Stable across replans."
  value       = docker_container.this.id
}

output "name" {
  description = "Container name (matches `docker ps`)."
  value       = docker_container.this.name
}

output "url" {
  description = "HTTP URL the service is reachable at on the host."
  value       = "http://localhost:${var.external_port}"
}

# `try(...)` guards against the count = 0 case (volume not created). Returning
# null is the documented "absent value" convention in Terraform.
output "volume_name" {
  description = "Name of the log volume when enable_log_volume is true; null otherwise."
  value       = try(docker_volume.logs[0].name, null)
}
