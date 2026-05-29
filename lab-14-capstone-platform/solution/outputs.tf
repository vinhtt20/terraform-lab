output "service_urls" {
  description = "Map of service name → URL."
  value       = { for k, m in module.web : k => m.url }
}

output "service_containers" {
  description = "Map of service name → container name."
  value       = { for k, m in module.web : k => m.container_name }
}
