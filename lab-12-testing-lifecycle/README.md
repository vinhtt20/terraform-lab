# Lab 12 — Testing & Lifecycle (`terraform test`, `replace_triggered_by`, `terraform_data`, `ephemeral`)

> **Cấp độ:** Expert
> **Thời lượng dự kiến:** ~90 phút
> **Yêu cầu trước:** Lab 00–11. Đặc biệt Lab 09 (state surgery) và Lab 11 (validation).
> **Phiên bản Terraform:** **>= 1.10.0** (cho `ephemeral`; nếu chỉ dùng các tính năng khác, >= 1.6 đủ).

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Hiểu `terraform_data`** — managed no-op resource giữ `input` và mirror sang
   `output`. Là "sentinel" để gắn các tín hiệu lifecycle vào.
2. **Dùng `replace_triggered_by`** — buộc Terraform thay thế resource khi 1
   resource/attribute khác thay đổi. Use case: credential rotation, cache busting.
3. **Viết test cho module bằng `terraform test`** — framework native (TF 1.6+),
   `.tftest.hcl` files với `run` blocks và `assert`. Apply thật, assert outputs.
4. **Hiểu `ephemeral`** (TF 1.10+) — variables/outputs/resources không persist
   vào state hay plan files. Use case: secrets transient, one-shot tokens.

## 🌐 Bối cảnh

Team Operations vừa public new policy: *"Mọi container đang chạy quá 30 ngày
phải rotate ít nhất 1 lần"*. Lý do: phòng compromise dài hạn. Câu hỏi: làm
sao rotate container đang trong Terraform mà không phải sửa attribute thật?

Câu trả lời: **`terraform_data` sentinel + `replace_triggered_by`**. Tăng
`var.rotation_id` = bump version → sentinel đổi → container replaced.

Phụ: bạn muốn yên tâm rằng config không bị regression khi thay đổi.
`terraform test` cho phép viết unit test trực tiếp lên module.

## 📋 Yêu cầu cụ thể

### File `starter/main.tf`

- [ ] Thêm `resource "terraform_data" "rotation" { input = var.rotation_id }`.
- [ ] Trong `lifecycle` của `docker_container.app`, thêm:
      `replace_triggered_by = [terraform_data.rotation]`.

### File `starter/outputs.tf`

- [ ] Thêm output `rotation_marker = terraform_data.rotation.output`.

### File `starter/tests/basic.tftest.hcl`

- [ ] Uncomment các assertion `rotation_marker == "v1"` và `== "v2"` (sau
      khi đã implement output).

### Workflow demo `replace_triggered_by`

- [ ] `terraform apply` với `rotation_id = "v1"` → note container ID
      (`docker ps -q --filter name=tflab-12-app`).
- [ ] `terraform apply -var "rotation_id=v2"` → container ID **đổi**
      (đã replace), không phải in-place update.

### Workflow test

- [ ] `terraform test` từ `starter/` → 2 run blocks pass.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể:

- `terraform fmt -check -recursive` sạch.
- `terraform validate` pass.
- `main.tf` có `resource "terraform_data"` và `replace_triggered_by`.
- `tests/basic.tftest.hcl` tồn tại và `terraform test` pass.
- Nếu đã `apply`: state có 3 entries (image, container, rotation); plan idempotent.

## 🧭 Hướng dẫn làm

```bash
cd starter

# 1) Thêm terraform_data + replace_triggered_by
$EDITOR main.tf

# 2) Thêm rotation_marker output
$EDITOR outputs.tf

# 3) Uncomment assertions trong test file
$EDITOR tests/basic.tftest.hcl

# 4) Init + apply
terraform init
terraform apply              # rotation_id=v1 (default)
CONTAINER_V1=$(docker ps -q --filter name=tflab-12-app)
echo "v1 container: $CONTAINER_V1"

# 5) Rotate
terraform apply -var "rotation_id=v2"
CONTAINER_V2=$(docker ps -q --filter name=tflab-12-app)
echo "v2 container: $CONTAINER_V2"
[ "$CONTAINER_V1" != "$CONTAINER_V2" ] && echo "✓ container REPLACED"

# 6) Test
terraform test
# Mong đợi: Success! 2 passed, 0 failed.

cd ..
bash verify.sh

# Dọn dẹp:
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert)

### `terraform_data` — vì sao tồn tại?

Trước TF 1.4: dùng `null_resource` cho mục đích tương tự. Vấn đề:
- `null_resource` thuộc provider riêng → init thêm 1 provider.
- API hơi awkward (`triggers` map).

`terraform_data` là replacement built-in:
- Không cần provider riêng.
- `input` argument tự động lưu/mirror vào `output`.
- Có thể dùng `triggers_replace` để self-replace khi giá trị đổi.

Use case ngoài rotation:
- **State migration helper:** giữ snapshot config cũ trong state để compare.
- **Cross-resource computation:** dùng `output` làm "computed local".
- **Dependency anchor:** `depends_on = [terraform_data.x]` để force ordering.

### `replace_triggered_by` — đặc thù

```hcl
lifecycle {
  replace_triggered_by = [
    terraform_data.rotation,           # bất kỳ attribute nào đổi
    terraform_data.config.output,      # chỉ attribute cụ thể
  ]
}
```

- Reference resource: replace khi **bất kỳ** attribute resource đó đổi.
- Reference attribute: replace khi **chính** attribute đó đổi.
- KHÔNG hỗ trợ `each.value` hoặc `count.index` (cần static reference).
- Trigger sau khi attribute KNOWN ở plan — unknown values trì hoãn.

So sánh với `replace`:
- `replace_triggered_by`: declarative trong code.
- `terraform apply -replace=ADDR`: imperative CLI; one-shot.

### `terraform test` — kiến trúc

Mỗi file `.tftest.hcl` là 1 test suite. Mỗi `run` block:
1. Build module-under-test (mặc định: working directory).
2. Apply (mặc định) hoặc plan.
3. Evaluate `assert` blocks.
4. (Tự động) teardown ở cuối suite — destroy mọi resource đã tạo.

`run` blocks chia sẻ state trong cùng suite — `run "x"` xong, `run "y"` thấy
state của x. Reset state: `state_key = "fresh"` hoặc dùng suite riêng.

`command`:
- `apply` (default): chạy plan + apply, đánh giá outputs.
- `plan`: chỉ plan, đánh giá plan output (`plan.resource_changes`).

`expect_failures`: assert rằng 1 variable/precondition fail:
```hcl
run "negative_test" {
  command = plan
  variables { base_port = 80 }
  expect_failures = [var.base_port]
}
```

### `ephemeral` — quy tắc thực tế (TF 1.10+)

**3 forms:**
1. **Ephemeral variable:** `variable "x" { ephemeral = true }`. Caller pass
   giá trị; Terraform không persist.
2. **Ephemeral resource:** `ephemeral "type" "name" { ... }`. Provider phải
   support. Vd: `random_password` (provider `hashicorp/random` 3.7+).
3. **Ephemeral output:** `output "x" { ephemeral = true }`. **CHỈ trong child
   module**, không phải root.

**Quy tắc dùng:**
- Ephemeral value chỉ reference được từ ephemeral context khác (provider
  config, ephemeral resource, ephemeral output, precondition/postcondition,
  validation).
- Reference từ persistent context (resource attribute, output non-ephemeral)
  → lỗi.

**Lý do lab này không có ephemeral demo trực tiếp:** lab là root module →
ephemeral output bị reject. Để demo đầy đủ, cần module con (xem lab 14
capstone).

**Use case:**
- DB password tạm thời pull từ vault.
- One-shot deploy token.
- Computed secret không nên show qua `terraform output`.

### `terraform test` workflow patterns

**Pattern 1 — Smoke test:** chạy default vars + assert outputs cơ bản.

**Pattern 2 — Boundary test:** vary input + assert behavior:
```hcl
run "min_port" { variables { external_port = 1024 } ... }
run "max_port" { variables { external_port = 65535 } ... }
```

**Pattern 3 — Negative test:** assert validation/precondition fail:
```hcl
run "invalid_port" {
  command = plan
  variables { external_port = 80 }
  expect_failures = [var.external_port]
}
```

**Pattern 4 — Cross-module test:** test 1 module reference module khác:
```hcl
run "setup" {
  module { source = "./fixtures/setup" }  # mock/fixture
  ...
}
run "actual_module" {
  ...
}
```

### Cạm bẫy thường gặp

1. **`replace_triggered_by` reference attribute unknown ở plan.** Plan sẽ
   trì hoãn; có thể không trigger đúng lúc.
2. **`terraform_data` "input" thay đổi nhưng container không replace.**
   Check syntax: `replace_triggered_by = [terraform_data.rotation]` (resource
   address) hoặc `[terraform_data.rotation.output]` (specific attr). Sai
   thường là quên brackets.
3. **`terraform test` không thấy file `.tftest.hcl`.** Default discovery
   là `tests/` directory. Hoặc cùng folder với config. Custom path:
   `terraform test -test-directory=./mytests`.
4. **Test apply thật tốn tài nguyên.** Mỗi `run` apply + destroy → chậm.
   Dùng `command = plan` cho test rẻ + reserve `apply` cho integration.
5. **`expect_failures` không dùng cho output assertion fail.** Chỉ cho
   variable/precondition. Output sai → `assert` block fail bình thường.

### Docs tham khảo

- `terraform_data`: <https://developer.hashicorp.com/terraform/language/resources/terraform-data>
- `replace_triggered_by`: <https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#replace_triggered_by>
- `terraform test`: <https://developer.hashicorp.com/terraform/language/tests>
- Ephemeral resources: <https://developer.hashicorp.com/terraform/language/resources/ephemeral>
- Ephemeral variables: <https://developer.hashicorp.com/terraform/language/values/variables#ephemeral>

## 🆘 Bí quá?

Mở `HINTS.md`.
