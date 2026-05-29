# =====================================================================
# Lab 08 — STARTER: declarative bulk import via `import {}` blocks.
#
# Workflow (xem README "Hướng dẫn làm" để biết chi tiết):
#   1. `bash setup.sh` ở root lab — tạo legacy stack ngoài Terraform.
#   2. Khai báo `import {}` block trong `imports.tf`.
#   3. `terraform plan -generate-config-out=generated.tf`
#      → Terraform sinh khung resource block "thô".
#   4. Refactor generated.tf → main.tf (gộp for_each, locals, đặt tên đẹp).
#      Update `to = ...` trong imports.tf cho khớp address mới.
#   5. `terraform apply` — 6 resource vào state, hạ tầng không thay đổi.
#   6. `terraform plan` → 0 changes.
#   7. (Tuỳ chọn) xoá imports.tf — hoặc giữ làm audit log.
# =====================================================================

# TODO M1: locals.apps   = map(name → { port, volume })
# TODO M2: locals.volumes = toset(["data1", "data2"])
# TODO M3: docker_image "nginx"   (declared bình thường, không import)
# TODO M4: docker_network "main"
# TODO M5: docker_volume "this"   với for_each = local.volumes
# TODO M6: docker_container "app" với for_each = local.apps
#          - networks_advanced { name = docker_network.main.name }
#          - ports { internal = 80, external = each.value.port }
#          - dynamic "volumes" chỉ render khi each.value.volume != null
#          - các attribute để zero-diff: restart, must_run, network_mode,
#            log_driver, … (đọc state show sau import).
