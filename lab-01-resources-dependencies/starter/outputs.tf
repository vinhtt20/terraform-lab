# TODO: khai báo ba output đúng tên & đúng giá trị (xem README "Yêu cầu cụ thể").
#
#   - network_id : docker_network.app.id
#   - web_url    : "http://localhost:8081"
#   - containers : list tên container [web, db]
#
# Khung dưới đã validate; bạn chỉ cần sửa `value`.

output "network_id" {
  description = "Docker network ID that both web and db are attached to."
  value       = "TODO-replace-with-docker_network.app.id"
}

output "web_url" {
  description = "URL where the nginx (web) container can be reached."
  value       = "TODO-replace-with-http://localhost:8081"
}

output "containers" {
  description = "Names of all containers managed by this lab."
  value       = ["TODO-web", "TODO-db"]
}
