# TODO: hoàn thiện 4 output:
#   - urls           : map { service_name => "http://localhost:<port>" }
#   - service_count  : length(var.services)
#   - created_at     : local.rendered_at
#   - container_names: list tên container, sort theo key services

output "urls" {
  description = "Map of service name to URL."
  value       = {}
}

output "service_count" {
  description = "Number of services."
  value       = 0
}

output "created_at" {
  description = "Plan-time timestamp."
  value       = "TODO"
}

output "container_names" {
  description = "Names of all deployed containers."
  value       = []
}
