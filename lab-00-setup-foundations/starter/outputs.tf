# TODO: khai báo hai output sau, đúng tên và đúng giá trị.
#
#   - container_id : ID đầy đủ của container vừa tạo
#                    (gợi ý: docker_container.hello.id)
#   - url          : "http://localhost:8080"
#
# Skeleton dưới đây đã validate được, bạn chỉ cần sửa lại `value`.

output "container_id" {
  description = "Full Docker container ID of the nginx instance."
  value       = "TODO-replace-with-docker_container.hello.id"
}

output "url" {
  description = "URL where the running nginx container can be reached."
  value       = "TODO-replace-with-http://localhost:8080"
}
