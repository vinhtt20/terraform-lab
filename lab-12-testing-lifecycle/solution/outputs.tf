output "container_name" {
  value = docker_container.app.name
}

output "url" {
  value = "http://localhost:${docker_container.app.ports[0].external}"
}

output "rotation_marker" {
  description = "Current rotation marker (mirrors var.rotation_id)."
  value       = terraform_data.rotation.output
}
