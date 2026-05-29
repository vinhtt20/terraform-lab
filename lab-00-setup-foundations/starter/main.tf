# =====================================================================
# Lab 00 — TODO: hoàn thiện file này.
#
# Hai resource bên dưới ĐÃ valid (chạy `terraform validate` PASS) nhưng
# chưa đúng yêu cầu của lab. Bạn cần thay các giá trị placeholder để
# khớp với mục "Yêu cầu cụ thể" trong README.md.
#
# Quy ước:
#   - Không xoá block, chỉ sửa giá trị bên trong.
#   - Sau khi sửa, chạy `terraform fmt` rồi `terraform validate`.
# =====================================================================

# TODO 1: image phải là "nginx:1.27-alpine".
resource "docker_image" "nginx" {
  name         = "PLACEHOLDER:replace-me"
  keep_locally = true
}

# TODO 2:
#   - name      = "tflab-00-hello"
#   - image     = tham chiếu tới docker_image.nginx.image_id ở trên
#   - ports     = block với internal = 80, external = 8080
#   - restart   = "unless-stopped"
resource "docker_container" "hello" {
  name  = "PLACEHOLDER-replace-me"
  image = "PLACEHOLDER:replace-me"

  # TODO: bỏ comment block ports và điền internal/external đúng.
  # ports {
  #   internal = 0
  #   external = 0
  # }

  # TODO: đặt restart policy phù hợp.
  restart = "no"
}
