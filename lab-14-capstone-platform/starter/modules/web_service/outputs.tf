output "container_name" {
  description = "Live container name."
  value       = docker_container.this.name
}

output "url" {
  description = "Public URL of the service."
  value       = "http://localhost:${docker_container.this.ports[0].external}"
}

# Ephemeral output (TF 1.10+) — works ONLY in child modules.
# Surfaced to the caller at apply time, NEVER persisted to state or plan files.
# Production use case: short-lived deploy token from a vault.
output "deploy_token" {
  description = "Short-lived deploy token. Ephemeral — not stored."
  value       = "deploy-${var.name}-${var.owner}"
  ephemeral   = true
  sensitive   = true
}
