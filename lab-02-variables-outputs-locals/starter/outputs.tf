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
  value       = []
}

output "ports" {
  description = "Host ports exposed by each replica."
  value       = []
}

# TODO: đánh dấu sensitive = true.
output "password" {
  description = "Admin password."
  value       = "TODO-replace-with-local.password_effective"
}

output "summary_path" {
  description = "Path to the generated JSON summary."
  value       = "TODO-replace-with-local_file.summary.filename"
}
