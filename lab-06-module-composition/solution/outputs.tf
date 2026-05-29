output "network_id" {
  description = "ID of the shared Docker network."
  value       = module.network.id
}

output "network_name" {
  description = "Name of the shared Docker network."
  value       = module.network.name
}

# Forward each region's URLs as a map { service_key => [urls] }. Using
# splat/for to flatten the per-instance outputs from the module's for_each.
output "services_east" {
  description = "Map of east-region service name to its list of replica URLs."
  value       = { for k, m in module.service_east : k => m.urls }
}

output "services_west" {
  description = "Map of west-region service name to its list of replica URLs."
  value       = { for k, m in module.service_west : k => m.urls }
}

output "container_names" {
  description = "Flat list of every container name created. Order is east-first, then west, alphabetic per region."
  value = concat(
    flatten([for k in sort(keys(module.service_east)) : module.service_east[k].container_names]),
    flatten([for k in sort(keys(module.service_west)) : module.service_west[k].container_names]),
  )
}
