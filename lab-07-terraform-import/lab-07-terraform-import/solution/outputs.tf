output "container_id" {
  description = "Docker container ID of the imported legacy app."
  value       = docker_container.legacy_app.id
}

output "volume_name" {
  description = "Name of the imported Docker volume."
  value       = docker_volume.legacy_data.name
}

output "url" {
  description = "HTTP URL the imported container is reachable at."
  value       = "http://localhost:${tolist(docker_container.legacy_app.ports)[0].external}"
}
