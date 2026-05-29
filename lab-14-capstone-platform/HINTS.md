# Hints — Lab 14 (Capstone)

> Capstone tổng hợp 13 lab trước. Mỗi bậc bung dần.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `module "web" { for_each = var.services }` — block source phải là folder
  path tương đối (`./modules/web_service`).
- Khi module dùng `for_each`, address là `module.web["api"]`. Output:
  `module.web["api"].url`.
- Aggregate outputs từ all instances: `{ for k, m in module.web : k => m.url }`.
- Rego policy walk module: `input.planned_values.root_module.child_modules[_].resources[_]`.
- `terraform test` cần state clean — chạy `terraform destroy` trước.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Root `main.tf`:**

```hcl
module "web" {
  for_each = var.services
  source   = "./modules/web_service"

  name      = each.key
  port      = each.value.port
  owner     = each.value.owner
  image_tag = each.value.image_tag
}

check "service_count_within_bounds" {
  assert {
    condition     = length(var.services) <= 5
    error_message = "Capstone supports up to 5 concurrent services."
  }
}
```

**Root `outputs.tf`:**

```hcl
output "service_urls" {
  value = { for k, m in module.web : k => m.url }
}

output "service_containers" {
  value = { for k, m in module.web : k => m.container_name }
}
```

**Policy `require_owner_label.rego`:**

```rego
package main

deny[msg] {
    resource := input.planned_values.root_module.child_modules[_].resources[_]
    resource.type == "docker_container"
    labels := { entry.label | entry := resource.values.labels[_] }
    not labels["owner"]
    msg := sprintf("docker_container %q missing required label 'owner'.",
                   [resource.address])
}
```

**Test assertions uncomment:**

```hcl
assert {
  condition     = output.service_urls["api"] == "http://localhost:8281"
  error_message = "api URL mismatch."
}
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

Xem `solution/` cho code hoàn chỉnh.

**Câu hỏi tự kiểm:**

> Vì sao module phải có `versions.tf` riêng?

Để pin version mà không phụ thuộc root. Khi share module qua git, ai pull về cũng
biết Terraform/provider requirements. Đồng thời `required_version = ">= 1.10.0"`
trong module là cách hợp đồng explicit.

> `ephemeral = true` không hoạt động trong root module nhưng OK trong child?

Đúng. Đây là quy tắc TF 1.10+: ephemeral output có nghĩa "consumer (caller) sẽ
tiếp nhận transient value". Root không có caller → invalid.

> Plan JSON cho `module.web["api"]` nằm ở đâu?

`input.planned_values.root_module.child_modules[i].resources[_]` với
`child_modules[i].address == "module.web[\"api\"]"`. Iterate tất cả child_modules
để cover for_each instances.

> `terraform test` báo "container name already exists". Sửa?

Run `terraform destroy` trước `terraform test`. Test framework apply ngay từ
clean state; nếu module đã apply real → conflict on container name.

> Tôi inject violation (xoá `owner` label trong module) — conftest có catch không?

Có, nếu policy walk `child_modules`. Test bằng: tạm thời sửa module/main.tf bỏ
labels block, chạy `bash ci-check.sh` → expect deny message.

> Capstone score của tôi 13/16 — nên improve gì?

Xem rubric trong README "Đào sâu". Thường improvement nhanh: thêm negative test
(`expect_failures`), validation đủ 4 input, output map keyed thay vì list.

</details>
