# TODO: hoàn thiện 4 output sau (xem README "Yêu cầu cụ thể").
#
#   - container_names : list tên container (theo thứ tự replica index)
#   - ports           : list số cổng host
#   - password        : sensitive, value = local.password_effective
#   - summary_path    : đường dẫn file summary
#
# Khung dưới validate nhưng giá trị/đánh dấu sensitive chưa đúng.

output "container_names" {
  description = "Names of all replica containers."
  value       = [for c in docker_container.app : c.name]
}

output "ports" {
  description = "Host ports exposed by each replica."
  value       = [for c in docker_container.app : tolist(c.ports)[0].external]
}

# TODO: đánh dấu sensitive = true.
output "password" {
  description = "Admin password (provided by caller or generated)."
  value       = local.password_effective
  sensitive   = true
}

output "summary_path" {
  description = "Path to the generated JSON summary."
  value       = local_file.summary.filename
}
