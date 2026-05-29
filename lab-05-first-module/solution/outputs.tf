output "urls" {
  description = "Map of service name to its localhost URL. Propagated from each module call."
  value = {
    api      = module.api.url
    frontend = module.frontend.url
  }
}

output "container_names" {
  description = "Names of every container created by the module calls."
  value = {
    api      = module.api.name
    frontend = module.frontend.name
  }
}

# Demo of output forwarding from a module. `volume_name` is null for the
# `api` module (enable_log_volume = false), so we only forward the frontend's.
output "frontend_volume" {
  description = "Log volume name for the frontend module. Null when enable_log_volume is false."
  value       = module.frontend.volume_name
}
