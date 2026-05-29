output "workspace_name" {
  description = "Active Terraform workspace name."
  value       = terraform.workspace
}

output "urls" {
  description = "Public URLs of containers in this workspace (ordered by count.index)."
  value       = [for c in docker_container.app : "http://localhost:${c.ports[0].external}"]
}

output "container_ids" {
  description = "Docker container IDs in this workspace (ordered by count.index)."
  value       = [for c in docker_container.app : c.id]
}
