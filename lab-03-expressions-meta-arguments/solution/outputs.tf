output "urls" {
  description = "Map of service name to its localhost URL."
  value = {
    for k, v in var.services :
    k => "http://localhost:${v.external_port}"
  }
}

output "service_count" {
  description = "Number of services deployed."
  value       = length(var.services)
}

output "created_at" {
  description = "Plan-time timestamp (RFC3339). Demo of plantimestamp()."
  value       = local.rendered_at
}

output "container_names" {
  description = "Names of all deployed containers, sorted alphabetically by service key."
  value       = [for k in sort(keys(var.services)) : docker_container.app[k].name]
}
