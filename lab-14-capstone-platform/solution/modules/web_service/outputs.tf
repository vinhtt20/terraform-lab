output "container_name" {
  description = "Live container name."
  value       = docker_container.this.name
}

output "url" {
  description = "Public URL of the service."
  value       = "http://localhost:${docker_container.this.ports[0].external}"
}

output "deploy_token" {
  description = "Short-lived deploy token. Ephemeral — not stored."
  value       = "deploy-${var.name}-${var.owner}"
  ephemeral   = true
  sensitive   = true
}
