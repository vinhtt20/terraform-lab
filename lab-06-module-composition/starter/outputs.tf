# =====================================================================
# Lab 06 — STARTER: outputs sau khi refactor.
#
# Hiện tại các output đang reference resource MONOLITH trực tiếp.
# Sau refactor, chúng phải reference qua module.
#
# Mục tiêu cuối:
#   network_id     = module.network.id
#   services_east  = { for k, m in module.service_east : k => m.urls }
#   services_west  = { for k, m in module.service_west : k => m.urls }
# =====================================================================

output "network_id" {
  description = "ID of the shared Docker network."
  value       = docker_network.platform.id
}

output "network_name" {
  description = "Name of the shared Docker network."
  value       = docker_network.platform.name
}

# TODO O1: thay bằng map { for k, m in module.service_east : k => m.urls }.
output "services_east" {
  description = "Map of east-region service name to its list of replica URLs."
  value = {
    web = [
      for k in sort(keys(docker_container.web)) :
      "http://localhost:${tolist(docker_container.web[k].ports)[0].external}"
    ]
    worker = ["http://localhost:8103"]
  }
}

# TODO O2: thay bằng map { for k, m in module.service_west : k => m.urls }.
output "services_west" {
  description = "Map of west-region service name to its list of replica URLs."
  value = {
    api = ["http://localhost:8102"]
  }
}

# TODO O3: container_names = concat( flatten(east...), flatten(west...) ).
