output "network_id" {
  description = "Docker network ID that both web and db are attached to."
  value       = docker_network.app.id
}

output "web_url" {
  description = "URL where the nginx (web) container can be reached."
  value       = "http://localhost:8081"
}

output "containers" {
  description = "Names of all containers managed by this lab."
  value       = [docker_container.web.name, docker_container.db.name]
}
