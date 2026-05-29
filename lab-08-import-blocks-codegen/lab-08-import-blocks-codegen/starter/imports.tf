# =====================================================================
# Lab 08 — STARTER: declarative imports.
#
# Khai báo 6 `import {}` block cho legacy stack. Khác classic CLI:
# import block là code — plannable, reviewable, chạy 1 lượt.
#
# `id` có thể là literal hoặc expression. Hai gợi ý:
#
#   • Volume & network: provider docker cho phép import bằng NAME →
#     id = "tflab-08-data1"  (chuỗi literal).
#
#   • Container: provider yêu cầu full container ID (dynamic). Dùng
#     `data "external"` để gọi `docker inspect` lấy ID ở plan time.
#
# Sau khi viết imports.tf:
#   terraform plan -generate-config-out=generated.tf
# Terraform sẽ sinh khung resource block — bạn refactor vào main.tf
# rồi update `to = ...` cho khớp address cuối.
# =====================================================================

# TODO I0: data "external" "container_ids" — emit JSON
#          {app1: "<id>", app2: "<id>", app3: "<id>"} bằng cách gọi
#          docker inspect --format '{{.Id}}' tflab-08-app{1,2,3}
#          (Hint: dùng jq -n --arg ... '{...}')

# TODO I1: import { to = docker_network.main, id = "tflab-08-net" }

# TODO I2: import block dùng for_each = local.volumes
#          to = docker_volume.this[each.key]
#          id = "tflab-08-${each.key}"
#
# Ví dụ tham khảo (commented):
# import {
#   for_each = local.volumes
#   to       = docker_volume.this[each.key]
#   id       = "tflab-08-${each.key}"
# }

# TODO I3: import block dùng for_each = local.apps
#          to = docker_container.app[each.key]
#          id = data.external.container_ids.result[each.key]
