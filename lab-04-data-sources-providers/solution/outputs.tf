output "digest" {
  description = "Sha256 digest of the nginx image, pulled from the registry data source."
  value       = data.docker_registry_image.nginx.sha256_digest
}

output "east_url" {
  description = "URL of the east region container."
  value       = "http://localhost:${tolist(docker_container.east.ports)[0].external}"
}

output "west_url" {
  description = "URL of the west region container."
  value       = "http://localhost:${tolist(docker_container.west.ports)[0].external}"
}

output "motd_sha256" {
  description = "Full sha256 of the motd file content (hex)."
  value       = sha256(data.local_file.motd.content)
}

# geoip is sensitive only because it would include the caller's public IP.
# Demonstrates wrapping optional data with try() to handle count = 0 gracefully.
output "geoip" {
  description = "Geoip response (null when enable_geoip = false)."
  value       = try(data.http.geoip[0].response_body, null)
  sensitive   = true
}
