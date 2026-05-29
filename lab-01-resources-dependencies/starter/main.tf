# =====================================================================
# Lab 01 — TODO: hoàn thiện file này.
#
# Khung dưới đã validate (cấu trúc resource đúng), nhưng giá trị là
# placeholder. Bạn sẽ:
#   1. Đặt đúng tên network/container theo README.
#   2. NỐI các resource lại với nhau bằng REFERENCE (implicit dependency).
#   3. Thêm EXPLICIT `depends_on` đúng chỗ để học cách dùng.
#   4. Map cổng 8081:80 cho container web.
#
# Đừng xoá block, chỉ sửa giá trị.
# =====================================================================

resource "docker_network" "app" {
  # TODO 1: đặt name = "tflab-01-net"
  name = "PLACEHOLDER-net"
}

resource "docker_image" "redis" {
  # TODO 2: redis:7-alpine
  name         = "PLACEHOLDER:replace-me"
  keep_locally = true
}

resource "docker_image" "nginx" {
  # TODO 3: nginx:1.27-alpine
  name         = "PLACEHOLDER:replace-me"
  keep_locally = true
}

resource "docker_container" "db" {
  # TODO 4: name = "tflab-01-db"
  name = "PLACEHOLDER-db"

  # TODO 5: tham chiếu image_id của docker_image.redis ở trên
  #         (KHÔNG hardcode chuỗi "redis:7-alpine").
  image = "PLACEHOLDER:replace-me"

  # TODO 6: gắn container vào docker_network.app — tham chiếu .name
  networks_advanced {
    name = "PLACEHOLDER-net"
  }

  restart = "unless-stopped"
}

resource "docker_container" "web" {
  # TODO 7: name = "tflab-01-web"
  name = "PLACEHOLDER-web"

  # TODO 8: tham chiếu image_id của docker_image.nginx
  image = "PLACEHOLDER:replace-me"

  # TODO 9: gắn container vào docker_network.app
  networks_advanced {
    name = "PLACEHOLDER-net"
  }

  # TODO 10: ports — internal 80, external 8081
  ports {
    internal = 0
    external = 0
  }

  restart = "unless-stopped"

  # TODO 11: thêm EXPLICIT dependency tới docker_container.db.
  # Lưu ý: không có attribute nào của db được web tham chiếu, nên Terraform
  # KHÔNG tự suy ra ordering này — phải dùng depends_on.
  # depends_on = [ ... ]
}
