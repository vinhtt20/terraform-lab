# Lab 14 — Capstone: Mini-Platform (Modules + Validation + Test + Policy)

> **Cấp độ:** Capstone (Expert)
> **Thời lượng dự kiến:** 2–3 giờ
> **Yêu cầu trước:** Lab 00–13 (toàn bộ).
> **Phiên bản Terraform:** >= 1.10.0 (cho ephemeral output trong module).
> **Phụ thuộc:** Docker daemon, `conftest` (optional cho policy gate).

## 🎯 Mục tiêu học

Capstone tổng hợp **mọi kỹ thuật** đã học:

1. **Module composition** (Lab 05–06) — child module `web_service` + root
   composition với `for_each`.
2. **Variable validation** (Lab 11) — input cấp module + cấp root.
3. **Postcondition** (Lab 11) — module assert label invariant.
4. **`check {}` block** (Lab 11) — root assert cap services.
5. **Ephemeral output** (Lab 12, TF 1.10+) — module trả token transient.
6. **`terraform test`** (Lab 12) — smoke + negative test.
7. **OPA/Conftest policy** (Lab 13) — `require_owner_label` policy walk
   child_modules.
8. **CI gating** (Lab 13) — `ci-check.sh` orchestrate plan + policy + test.

## 🌐 Bối cảnh

Bạn là platform engineer build mini-platform deploy nhiều "web services"
cùng lúc. Mỗi service:
- Có name, port, owner, image_tag riêng.
- Tuân thủ org policy: owner label bắt buộc, no `:latest`.
- Có ephemeral deploy token cho downstream CI (không lưu state).
- Test tự động chạy mỗi commit.
- CI gate: plan → policy → test → apply.

## 📋 Yêu cầu cụ thể

### `starter/main.tf`

- [ ] Instantiate `module "web"` với `for_each = var.services`, source
      `./modules/web_service`, pass đủ 4 input (name, port, owner, image_tag).
- [ ] Thêm top-level `check "service_count_within_bounds" {}` block.

### `starter/outputs.tf`

- [ ] Output `service_urls` = map `{ service_name => url }`.
- [ ] Output `service_containers` = map `{ service_name => container_name }`.

### `starter/policies/require_owner_label.rego`

- [ ] Viết `deny` rule walk `child_modules[_].resources[_]`, filter
      `docker_container`, deny nếu thiếu `owner` label.

### `starter/tests/basic.tftest.hcl`

- [ ] Uncomment 2 assertions trong `run "smoke"` (sau khi outputs đã viết).

### Workflow

- [ ] `terraform init && terraform apply` → 2 service (api, web) live.
- [ ] `terraform test` → 2 runs PASS.
- [ ] `bash ci-check.sh` → plan + (conftest if installed) + test all green.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể:

- fmt, validate pass.
- module web_service có 4 file (.tf) + ephemeral output.
- root main.tf: module call với for_each + check block.
- policy có `deny[...]` rule.
- test file tồn tại.
- `terraform test` PASS (khi state clean).
- ci-check.sh tồn tại.
- (nếu state có) `module.web["api"]` và `module.web["web"]` trong state.

## 🧭 Hướng dẫn làm

```bash
cd starter

# 1) Module web_service đã hoàn chỉnh sẵn (xem modules/web_service/). Đọc kỹ.

# 2) Hoàn thiện root main.tf, outputs.tf
$EDITOR main.tf outputs.tf

# 3) Viết Rego policy
$EDITOR policies/require_owner_label.rego

# 4) Uncomment test assertions
$EDITOR tests/basic.tftest.hcl

# 5) Validate
terraform init
terraform validate
terraform fmt -recursive

# 6) Apply
terraform apply
docker ps --filter name=tflab-14-

# 7) Test
terraform destroy   # clean state để terraform test không conflict
terraform test

# 8) CI gate
terraform apply
bash ci-check.sh

# 9) Verify
cd ..
bash verify.sh

# Dọn dẹp:
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert) — Rubric Self-Grading

Sử dụng rubric này để chấm chính bài bạn (hoặc cho người khác review):

| Tiêu chí | 0 (Fail) | 1 (Partial) | 2 (Full) |
|---|---|---|---|
| **Module API design** | Module ko có validation hoặc thiếu input | Validation 1 input | Validation đủ 4 input + postcondition |
| **Root composition** | Hardcode resource | `count` cho replication | `for_each` map cho services |
| **Output aggregation** | Output dạng single value | Output list | Output map keyed by service name |
| **Policy** | Không có policy hoặc TODO | Policy compile nhưng không catch violation | Policy reject test injection |
| **Test** | Không có test | 1 run pass | Pos + negative (expect_failures) |
| **CI script** | Không có | Plan only | Plan + policy + test orchestrated |
| **Ephemeral usage** | Output thường | Sensitive output | Ephemeral output đúng context (child module) |
| **Documentation** | Không comment | Comment hỗn loạn | Module có description, var documented |

**Điểm tổng:** /16. Pass >= 12. Expert >= 14.

### Tham khảo workflow CI/CD đầy đủ (GitHub Actions)

```yaml
name: terraform-capstone-ci

on:
  pull_request:
    paths: ['lab-14-capstone-platform/**']

jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.10.0'
      - run: |
          curl -L https://github.com/open-policy-agent/conftest/releases/download/v0.55.0/conftest_0.55.0_Linux_x86_64.tar.gz | tar xz
          sudo mv conftest /usr/local/bin/

      - name: init
        run: terraform -chdir=lab-14-capstone-platform/starter init -lock=false

      - name: validate
        run: terraform -chdir=lab-14-capstone-platform/starter validate

      - name: plan + policy
        run: bash lab-14-capstone-platform/starter/ci-check.sh

      # apply chỉ trên main branch sau merge
      - name: apply
        if: github.ref == 'refs/heads/main'
        run: terraform -chdir=lab-14-capstone-platform/starter apply -auto-approve
```

### Module API conventions (best practices recap)

1. **Module có `versions.tf`** với required_version + required_providers. KHÔNG có
   `provider {}` block trong module (truyền từ root nếu cần alias).
2. **Mọi input có `description`** + `type` + `validation` khi áp dụng.
3. **Output có `description`**.
4. **`ephemeral = true`** cho output không nên persist (TF 1.10+, child only).
5. **`sensitive = true`** kèm `ephemeral` cho secret-like values.
6. **Module nội bộ:** prefix với `_` hoặc đặt trong `internal/` nếu có (TF chưa
   support visibility — convention).

## 🆘 Bí quá?

Mở `HINTS.md`.
