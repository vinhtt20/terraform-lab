output "container_names" {
  description = "Names of all replica containers, in order of replica index."
  value       = [for c in docker_container.app : c.name]
}

output "ports" {
  description = "Host ports exposed by each replica."
  value       = [for c in docker_container.app : tolist(c.ports)[0].external]
}

# Sensitive prevents `terraform output password` from printing the value;
# use `terraform output -raw password` to read it explicitly.
output "password" {
  description = "Admin password (provided by caller or generated)."
  value       = local.password_effective
  sensitive   = true
}

output "summary_path" {
  description = "Absolute path to the generated JSON summary file."
  value       = local_file.summary.filename
}
