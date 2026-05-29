output "container_name" {
  value = docker_container.app.name
}

output "url" {
  value = "http://localhost:${docker_container.app.ports[0].external}"
}

# TODO — add an output that surfaces the current rotation_id from the
# `terraform_data.rotation` sentinel:
#
# output "rotation_marker" {
#   description = "Current rotation marker (mirrors var.rotation_id)."
#   value       = terraform_data.rotation.output
# }
#
# NOTE — ephemeral outputs (TF 1.10+) work only in CHILD modules, not the
# root module. See README "Đào sâu" for details on where ephemeral applies.
