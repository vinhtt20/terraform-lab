# Hints — Lab 12

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `terraform_data` là resource built-in (TF 1.4+), không cần provider riêng.
  Có 2 argument: `input` (giá trị input) và `triggers_replace` (optional).
- `output` attribute tự động mirror `input`. Vd: `input = "v1"` →
  `output = "v1"`.
- `replace_triggered_by` đặt trong `lifecycle {}`, là LIST không phải single.
- Reference resource (không attribute): `[terraform_data.x]` → bất kỳ attribute
  thay đổi cũng trigger. Reference attribute: `[terraform_data.x.output]`.
- `terraform test` mặc định tìm `tests/*.tftest.hcl` trong working directory.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**`main.tf` — thêm terraform_data + replace_triggered_by:**

```hcl
resource "terraform_data" "rotation" {
  input = var.rotation_id
}

resource "docker_container" "app" {
  # ... (existing config)

  lifecycle {
    replace_triggered_by = [terraform_data.rotation]
    ignore_changes       = [log_opts]
  }
}
```

**`outputs.tf` — thêm rotation_marker:**

```hcl
output "rotation_marker" {
  description = "Current rotation marker (mirrors var.rotation_id)."
  value       = terraform_data.rotation.output
}
```

**`tests/basic.tftest.hcl` — uncomment assertions:**

```hcl
run "initial_apply" {
  command = apply
  # ... existing asserts ...
  assert {
    condition     = output.rotation_marker == "v1"
    error_message = "rotation_marker must mirror rotation_id."
  }
}

run "rotation_changes_marker" {
  command = apply
  variables {
    rotation_id   = "v2"
    external_port = 8241
  }
  assert {
    condition     = output.rotation_marker == "v2"
    error_message = "rotation_marker should follow rotation_id."
  }
}
```

**Test replace_triggered_by hoạt động:**

```bash
terraform apply -auto-approve                          # rotation_id=v1
docker inspect tflab-12-app --format '{{.Id}}'         # note ID

terraform apply -auto-approve -var "rotation_id=v2"    # rotate
docker inspect tflab-12-app --format '{{.Id}}'         # ID phải KHÁC
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**`main.tf` hoàn chỉnh:**

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "terraform_data" "rotation" {
  input = var.rotation_id
}

resource "docker_container" "app" {
  name  = "tflab-12-app"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    replace_triggered_by = [terraform_data.rotation]
    ignore_changes       = [log_opts]
  }
}
```

**`outputs.tf` hoàn chỉnh:**

```hcl
output "container_name" {
  value = docker_container.app.name
}

output "url" {
  value = "http://localhost:${docker_container.app.ports[0].external}"
}

output "rotation_marker" {
  description = "Current rotation marker (mirrors var.rotation_id)."
  value       = terraform_data.rotation.output
}
```

**Câu hỏi tự kiểm:**

> Vì sao container ID đổi khi tôi đổi `rotation_id`?

`var.rotation_id` thay đổi → `terraform_data.rotation.input` đổi → attribute
`output` đổi (mirror) → `replace_triggered_by` thấy attribute mới → Terraform
force-replace container.

> Tôi apply 2 lần liên tiếp với cùng `rotation_id`. Container có replace không?

KHÔNG. `terraform_data.rotation.output` không đổi → no trigger → plan no-op.

> `terraform test` chạy mất bao lâu?

Mỗi `run` block là 1 apply + tear-down. Mỗi apply tạo container thật mất
~3-5s, destroy ~1s. 2 runs ≈ 10-15s tổng. Để nhanh hơn, dùng
`command = plan` thay vì `apply` cho tests không cần real infra.

> Tôi muốn rotate mà KHÔNG đổi `rotation_id`. Cách khác?

3 cách:
1. `terraform apply -replace=docker_container.app` (CLI imperative).
2. Đổi `terraform_data.rotation.triggers_replace` list (in-config).
3. Bump version constraint trong code → đổi image_id → trigger replace.

> `terraform test` của tôi báo `Error: Reference to undeclared input variable`.
> Variable đã khai báo trong `starter/variables.tf`. Tại sao?

Test file cũng cần khai báo variable nếu dùng. Block `variables {}` ở đầu
file `.tftest.hcl` set giá trị, nhưng nếu reference `var.x` trong assert,
Terraform tự pickup từ module-under-test. Check syntax.

> `replace_triggered_by` có liệt kê được data source không?

Có. Data source attribute đổi → trigger. Vd:
```hcl
replace_triggered_by = [data.http.config_version.body]
```
Hữu ích cho rolling restart khi external config bump version.

</details>
