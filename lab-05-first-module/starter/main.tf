# =====================================================================
# Lab 05 — TODO: hoàn thiện file này.
#
# Khung dưới validate được nhưng chưa đầy đủ:
#   - module "api" đã được viết sẵn làm VÍ DỤ — đọc kỹ.
#   - module "frontend" còn THIẾU — bạn phải tự viết (TODO M1..M3).
#   - Module child `./modules/web_service/` cũng còn nhiều TODO trong
#     variables.tf, main.tf, outputs.tf.
# =====================================================================

resource "random_id" "build" {
  byte_length = 4
}

# ----- VÍ DỤ — call #1 — KHÔNG sửa block này. ------------------------
# Đây là cách gọi module chuẩn: source là path tương đối, các argument
# tương ứng với input variable trong modules/web_service/variables.tf.
module "api" {
  source = "./modules/web_service"

  name          = "api"
  image         = var.image
  external_port = 8093

  labels = {
    role = "backend"
    tier = "api"
  }
}

# ----- TODO M1 — call #2 — frontend service --------------------------
# Yêu cầu:
#   - source = "./modules/web_service"
#   - name = "frontend"
#   - image = var.image
#   - external_port = 8094
#   - enable_log_volume = true
#   - index_content = templatefile(
#       "${path.module}/templates/frontend.html.tftpl",
#       { title = "tflab-05 Frontend", build_id = random_id.build.hex },
#     )
#   - labels = { role = "frontend", tier = "web" }
#
# TODO M1: viết block module "frontend" {...} ngay dưới comment này.

# ----- TODO M2 — outputs --------------------------------------------
# Mở outputs.tf và điền các output còn trống ở đó.

# ----- TODO M3 — module child ---------------------------------------
# Mở modules/web_service/{variables,main,outputs}.tf và hoàn thành các
# TODO bên trong. Module chính là nơi LÀM CHÍNH của lab này.
