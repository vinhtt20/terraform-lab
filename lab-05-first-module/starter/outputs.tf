output "urls" {
  description = "Map of service name to its localhost URL."
  # TODO O1: { api = module.api.url, frontend = module.frontend.url }
  value = {
    api = module.api.url
  }
}

# TODO O2: thêm output "container_names" — map { api = module.api.name, frontend = module.frontend.name }.

# TODO O3: thêm output "frontend_volume" — value = module.frontend.volume_name.
