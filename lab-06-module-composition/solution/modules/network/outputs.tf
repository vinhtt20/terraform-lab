output "id" {
  description = "Docker network ID (full SHA)."
  value       = docker_network.this.id
}

output "name" {
  description = "Docker network name (as appears in `docker network ls`)."
  value       = docker_network.this.name
}
