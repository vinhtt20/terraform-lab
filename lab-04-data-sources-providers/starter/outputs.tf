# TODO: hoàn thiện 5 output (xem README "Yêu cầu cụ thể"):
#   - digest       : data.docker_registry_image.nginx.sha256_digest
#   - east_url     : http://localhost:<port>
#   - west_url     : http://localhost:<port>
#   - motd_sha256  : sha256(data.local_file.motd.content)
#   - geoip        : try(data.http.geoip[0].response_body, null), sensitive

output "digest" {
  description = "Sha256 digest of the nginx image."
  value       = "TODO"
}

output "east_url" {
  description = "URL of the east region container."
  value       = "TODO"
}

output "west_url" {
  description = "URL of the west region container."
  value       = "TODO"
}

output "motd_sha256" {
  description = "Full sha256 of the motd file content (hex)."
  value       = "TODO"
}

# TODO: đánh dấu sensitive = true.
output "geoip" {
  description = "Geoip response (null when disabled)."
  value       = null
}
