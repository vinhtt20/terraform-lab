output "names" {
  description = "Container names (ordered by count.index)."
  value       = [for c in docker_container.app : c.name]
}

output "urls" {
  description = "Public URLs of containers (ordered by count.index)."
  value       = [for c in docker_container.app : "http://localhost:${c.ports[0].external}"]
}
