# =====================================================================
# Lab 07 — STARTER: classic `terraform import` workflow.
#
# Mục tiêu: đưa 1 container + 1 volume đã được tạo NGOÀI Terraform
# (xem setup.sh) vào state, KHÔNG destroy/recreate (zero downtime).
#
# Workflow:
#   1. Viết resource block ESTIMATE cho từng resource bên dưới.
#      Không cần khớp 100% — bạn sẽ tinh chỉnh sau khi import.
#   2. Chạy lệnh import (xem README phần "Hướng dẫn làm"):
#        terraform import docker_volume.legacy_data tflab-07-legacy-data
#        terraform import docker_container.legacy_app <container_id>
#   3. `terraform plan` — đọc diff cẩn thận. Tinh chỉnh attribute trong
#      block bên dưới đến khi plan báo "No changes".
#   4. `terraform apply` (chỉ refresh, không destroy).
#
# Gợi ý: dùng `terraform state show <addr>` SAU khi import để lấy
# attribute thực tế từ live resource, rồi copy về block bên dưới.
# =====================================================================

# TODO C1: viết resource "docker_image" "nginx" — name = "nginx:1.27-alpine".
#          (Image KHÔNG import; declare bình thường, provider sẽ skip pull
#          nếu đã có ở local.)

# TODO C2: viết resource "docker_volume" "legacy_data" — chỉ cần `name`.

# TODO C3: viết resource "docker_container" "legacy_app".
#          Các attribute tối thiểu phải có:
#            - name  = "tflab-07-legacy-app"
#            - image = docker_image.nginx.image_id
#            - ports { internal = 80, external = 8110 }
#            - volumes { volume_name = ..., container_path = "/var/data" }
#            - restart = "unless-stopped"
#          Sau khi import, plan sẽ chỉ ra các attribute còn diff
#          (network_mode, log_driver, must_run, …). Bổ sung dần.
#
#          GOTCHA: `log_opts` được Docker daemon assign default trên host
#          (xem `docker info`). Khác máy → giá trị khác. Đây là trường hợp
#          hợp lệ để dùng:
#            lifecycle { ignore_changes = [log_opts] }
#          Đọc README "Đào sâu" cho lý do.
