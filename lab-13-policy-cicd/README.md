# Lab 13 — Policy as Code (OPA/Conftest) + CI/CD Gating

> **Cấp độ:** Expert
> **Thời lượng dự kiến:** ~75 phút
> **Yêu cầu trước:** Lab 00–12. Hiểu Terraform plan JSON output.
> **Phụ thuộc thêm:** `conftest` CLI — `brew install conftest` (macOS) hoặc xem
> <https://www.conftest.dev/install/>.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Hiểu Policy-as-Code** — viết quy tắc tổ chức bằng code (Rego), version
   control, review qua PR. Loại bỏ "tribal knowledge".
2. **Đọc Terraform plan JSON** — cấu trúc `planned_values.root_module.resources`,
   biết extract `type`, `address`, `values.*`.
3. **Viết Rego policies với OPA/Conftest** — `package`, `deny[msg]`, comprehension
   trên list, `sprintf` cho message.
4. **Tích hợp policy check vào CI/CD** — pipeline pattern: `plan → show -json
   → conftest test → apply`. Gating ở bước nào, fail-fast ở đâu.
5. **So sánh với Sentinel, Checkov, Terraform Cloud Policy Sets** — biết khi
   nào dùng cái nào.

## 🌐 Bối cảnh

Sau khi áp dụng `validation`/`precondition`/`check {}` (lab 11) trong code,
team có 1 lớp safety net. Nhưng:
- Validation chỉ block 1 module. Quy mô tổ chức cần check ACROSS mọi module.
- Không phải dev nào cũng viết validation. Bạn cần lớp gating "tree-wide".
- Compliance team muốn audit độc lập, không sửa code module.

→ **Policy as Code** ngoài module. Conftest đọc plan JSON, áp Rego policy,
gating apply ở CI/CD. Cùng 1 policy chạy cho mọi config trong org.

## 📋 Yêu cầu cụ thể

### Cài conftest (lần duy nhất)

- [ ] `brew install conftest` (macOS). Verify: `conftest --version`.

### File `starter/policies/no_latest_tag.rego`

- [ ] Viết 2 `deny` rule trong `package main`:
  - Deny `docker_image` resources có `values.name` kết thúc `:latest`.
  - Deny `docker_image` resources có `values.name` KHÔNG chứa `:` (no tag).

### File `starter/policies/require_owner_label.rego`

- [ ] Viết 1 `deny` rule:
  - Iterate `docker_container` resources.
  - Build set tên labels.
  - Deny nếu `"owner"` không có trong set.

### Run gating

- [ ] `bash starter/ci-check.sh` → exit 0 (config sạch passes).
- [ ] Thử inject violation (thêm `resource "docker_image" "bad" { name = "x:latest" }`),
      chạy `ci-check.sh` → exit non-zero với message chỉ rõ violation.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể:

- fmt, validate pass.
- `policies/no_latest_tag.rego` và `policies/require_owner_label.rego` có
  `deny[...]` rule (không chỉ TODO).
- `ci-check.sh` tồn tại + executable.
- Nếu `conftest` cài: ci-check.sh pass cho compliant config; reject :latest
  injection.

## 🧭 Hướng dẫn làm

```bash
cd starter

# 1) Viết logic Rego trong policies/*.rego
$EDITOR policies/no_latest_tag.rego policies/require_owner_label.rego

# 2) Chạy gating local
terraform init
bash ci-check.sh
# Mong đợi: "0 failures" (config sạch passes).

# 3) Test negative: inject violation
cat > /tmp/violation.tf <<'EOF'
resource "docker_image" "bad" {
  name         = "alpine:latest"
  keep_locally = true
}
EOF
cp /tmp/violation.tf .
bash ci-check.sh
# Mong đợi: exit non-zero, message ":latest tag — forbidden".
rm violation.tf

cd ..
bash verify.sh
```

## 🧠 Đào sâu (expert)

### Plan JSON cấu trúc

```jsonc
{
  "format_version": "1.2",
  "terraform_version": "1.10.x",
  "planned_values": {
    "root_module": {
      "resources": [
        {
          "address": "docker_image.app",
          "mode":    "managed",
          "type":    "docker_image",
          "name":    "app",
          "provider_name": "registry.terraform.io/kreuzwerker/docker",
          "schema_version": 2,
          "values": {
            "name":         "nginx:1.27-alpine",
            "keep_locally": true,
            // ...
          }
        }
      ],
      "child_modules": [ /* nested */ ]
    }
  },
  "resource_changes": [ /* old vs new */ ],
  "configuration": { /* raw config */ }
}
```

`planned_values` = "trạng thái sau apply" (predicted). `resource_changes`
chứa diff (create/update/delete/replace). Policies thường đọc `planned_values`
cho "what will exist"; đọc `resource_changes` cho "what is changing".

### Rego basics dành cho Terraform

```rego
package main

# Iterate
deny[msg] {
    r := input.planned_values.root_module.resources[_]
    r.type == "docker_image"
    # ... condition ...
    msg := sprintf("violation: %s", [r.address])
}

# Helper: extract labels as set
labels_set(resource) = labels {
    labels := { entry.label | entry := resource.values.labels[_] }
}

# Negation
deny[msg] {
    r := input.planned_values.root_module.resources[_]
    r.type == "docker_container"
    not labels_set(r)["owner"]
    msg := sprintf("missing owner label: %s", [r.address])
}
```

Quy tắc:
- Một file = một `package` (đa số dùng `main`).
- `deny[msg]` là set comprehension; mỗi iteration emit 1 msg.
- `_` trong `[_]` là "any index" — duyệt tất cả.
- `not expr` đảo bool; cẩn thận với "undefined" (xem docs OPA).

### `child_modules` — quy tắc đệ quy

Mọi child module nằm trong `child_modules`. Để check cả mod gốc + child:

```rego
walk_resources[r] {
    r := input.planned_values.root_module.resources[_]
}
walk_resources[r] {
    r := input.planned_values.root_module.child_modules[_].resources[_]
}
# (hoặc dùng `walk(input, [path, value])` của OPA cho generic)
```

### CI/CD gating patterns

**Pattern 1 — Plan-then-Gate (đa số):**

```yaml
# GitHub Actions
- name: terraform plan
  run: terraform plan -out=tfplan
- name: show json
  run: terraform show -json tfplan > plan.json
- name: conftest test
  run: conftest test plan.json --policy policies/
- name: terraform apply
  if: success()
  run: terraform apply tfplan
```

Apply chỉ chạy nếu Conftest pass. Exit non-zero = gate.

**Pattern 2 — Pre-merge gate (PR pipeline):**

PR opened → run `plan -no-color -lock=false` + conftest → comment in PR.
Merge blocked until policy clean. KHÔNG apply.

**Pattern 3 — Continuous compliance (out-of-band):**

Daily cron: `plan -refresh-only` mọi state, dump json, run conftest. Alert
nếu drift tạo violation. Independent của dev workflow.

### `warn` vs `deny`

```rego
warn[msg] { /* ... */ }   # exit 0 nhưng print
deny[msg] { /* ... */ }   # exit non-zero
```

Dùng `warn` cho "best practice" (cost, naming convention); `deny` cho
"absolute" (security, compliance).

### So sánh policy frameworks

| Framework | Engine | Cài đặt | Use case |
|---|---|---|---|
| **OPA/Conftest** | Rego | CLI binary | DIY, generic JSON gating, open-source |
| **HashiCorp Sentinel** | Sentinel | TF Cloud/Enterprise | Built-in cho TFC, expressive |
| **Checkov** | Python rules | CLI, pre-built rules | Security scanning, AWS/Azure/GCP heavy |
| **tfsec / Trivy** | Go rules | CLI | Quick security scan, free |
| **OPA Gatekeeper** | Rego | K8s admission webhook | K8s-native, not TF |

Quy tắc thực dụng:
- Mới bắt đầu, đơn giản → **Checkov** (rule sẵn).
- Cần custom logic, multi-target (TF + K8s + Dockerfile) → **Conftest**.
- TF Cloud paying → **Sentinel** (deeper integration).

### Cạm bẫy thường gặp

1. **`input.planned_values.root_module.resources` rỗng cho compute resources
   với unknown values.** Plan chưa biết hết — dùng `input.configuration`
   thay vì `planned_values` cho phần này.
2. **Quên `package main`.** Conftest default namespace là `main`. File
   không có package → error.
3. **Rego `not` với undefined.** `not labels.owner` fail nếu `labels` không
   tồn tại — đảm bảo `labels` được build trước.
4. **JSON path sai cho list.** Docker labels là `[ { label, value } ]`,
   không phải map. Convert qua comprehension trước.
5. **CI chỉ run policy mà không init Terraform.** Plan cần init. Order:
   `terraform init` → `plan -out` → `show -json` → conftest.
6. **Conftest exit 0 khi policy không tìm thấy file.** Lúc đầu chưa có
   `.rego` → conftest pass — đánh lừa CI! Verify số file: `[ -n "$(ls
   policies/*.rego)" ]`.

### Docs tham khảo

- Conftest: <https://www.conftest.dev/>
- OPA Rego basics: <https://www.openpolicyagent.org/docs/latest/policy-language/>
- Terraform plan JSON: <https://developer.hashicorp.com/terraform/internals/json-format>
- HashiCorp Sentinel: <https://developer.hashicorp.com/sentinel>
- Checkov: <https://www.checkov.io/>

## 🆘 Bí quá?

Mở `HINTS.md`.
