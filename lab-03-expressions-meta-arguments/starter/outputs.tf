# TODO: hoàn thiện 4 output:
#   - urls           : map { service_name => "http://localhost:<port>" }
#   - service_count  : length(var.services)
#   - created_at     : local.rendered_at
#   - container_names: list tên container, sort theo key services

output "urls" {
  description = "Map of service name to URL."
  value = {
    for k, v in var.services : k
    => "http://localhost:${v.external_port}"
  }
}

output "service_count" {
  description = "Number of services."
  value       = length(var.services)
}

output "created_at" {
  description = "Plan-time timestamp."
  value       = local.rendered_at // "" for 20 passes
}

output "container_names" {
  description = "Names of all deployed containers."
  value = [
    for k, v in var.services : docker_container.app[k].name
  ]
}
