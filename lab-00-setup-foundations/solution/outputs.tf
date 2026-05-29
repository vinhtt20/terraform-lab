output "container_id" {
  description = "Full Docker container ID of the nginx instance."
  value       = docker_container.hello.id
}

output "url" {
  description = "URL where the running nginx container can be reached."
  value       = "http://localhost:8080"
}
