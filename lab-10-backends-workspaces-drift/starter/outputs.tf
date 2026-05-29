output "workspace_name" {
  description = "Active Terraform workspace name."
  value       = terraform.workspace
}

# TODO — implement the two outputs below. Both must be lists ordered by
# count.index so verify.sh can assert exact values.
#
# output "urls" {
#   description = "Public URLs of containers in this workspace."
#   value = [for c in docker_container.app : "http://localhost:${c.ports[0].external}"]
# }
#
# output "container_ids" {
#   description = "Docker container IDs in this workspace."
#   value       = [for c in docker_container.app : c.id]
# }
