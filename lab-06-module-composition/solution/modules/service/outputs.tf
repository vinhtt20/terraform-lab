output "container_names" {
  description = "Names of every replica container, sorted by replica index."
  value       = [for k in sort(keys(docker_container.this)) : docker_container.this[k].name]
}

output "urls" {
  description = "List of host URLs (one per replica), sorted by replica index."
  value       = [for k in sort(keys(docker_container.this)) : "http://localhost:${var.external_port + tonumber(k)}"]
}

output "image_id" {
  description = "Image ID actually deployed (full SHA)."
  value       = docker_image.this.image_id
}

output "replicas" {
  description = "Number of replicas deployed (echo of input for downstream tools)."
  value       = var.replicas
}
