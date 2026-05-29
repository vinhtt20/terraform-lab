output "urls" {
  description = "Map of app key → URL (http://localhost:<port>)."
  value = {
    for k, c in docker_container.app :
    k => "http://localhost:${tolist(c.ports)[0].external}"
  }
}

output "network_id" {
  description = "Docker network ID of the shared bridge network."
  value       = docker_network.main.id
}

output "volumes" {
  description = "Sorted list of Docker volume names managed by Terraform."
  value       = sort([for v in docker_volume.this : v.name])
}
