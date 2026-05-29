# Thiết kế: Bộ lab Terraform Cơ bản → Expert

> Spec ngày 2026-05-28. Đây là tài liệu chuẩn (source of truth) cho việc build & chấm bộ lab.

## 1. Mục tiêu

Tạo bộ lab thực hành Terraform đi từ cơ bản đến expert, đặc biệt nhấn mạnh **quản lý state** và
**import** state. Người học hoàn thành phải hiểu Terraform ở mức expert và bài tập phải đạt chuẩn
cao để một chuyên gia khác review lại.

## 2. Quyết định nền tảng (đã chốt với người dùng)

| Hạng mục | Quyết định | Lý do |
|---|---|---|
| Môi trường | Docker provider (`kreuzwerker/docker`) + local providers | Tài nguyên Docker là **thật & importable**, miễn phí, offline, review không tốn chi phí |
| Local providers | `null`, `random`, `local`, `tls`, `time`, `http` | Đủ dạy toàn bộ ngôn ngữ HCL & workflow mà không cần cloud |
| Công cụ | Terraform (>= 1.9, một số lab >= 1.10) | Chuẩn ngành; code tương thích OpenTofu |
| Ngôn ngữ | Hướng dẫn tiếng Việt; code/comment tiếng Anh | Theo yêu cầu người dùng |
| Giao hàng | đề + `solution/` + `verify.sh` + rubric | Chuẩn cao, chấm tự động được |

Môi trường thực tế đã kiểm tra: Terraform v1.14.9, Docker 29.4.0, jq 1.7.1. `conftest` chưa cài
(Lab 13 kèm hướng dẫn cài).

## 3. Provider versions (pin chuẩn)

```hcl
terraform {
  required_version = ">= 1.9.0"   # lab-12 nâng lên ">= 1.10.0" cho ephemeral
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
    random = { source = "hashicorp/random",   version = "~> 3.6" }
    null   = { source = "hashicorp/null",     version = "~> 3.2" }
    local  = { source = "hashicorp/local",    version = "~> 2.5" }
    tls    = { source = "hashicorp/tls",      version = "~> 4.0" }
    time   = { source = "hashicorp/time",     version = "~> 0.12" }
    http   = { source = "hashicorp/http",     version = "~> 3.4" }
  }
}
```

## 4. Lộ trình (14 lab + capstone)

**Level 0 — Nền tảng**
- `lab-00-setup-foundations` — cài & verify, config đầu tiên, vòng đời init/plan/apply/destroy
- `lab-01-resources-dependencies` — resources, dependency ngầm/tường minh, `state list/show` (nginx thật)

**Level 1 — Ngôn ngữ lõi**
- `lab-02-variables-outputs-locals` — variables (type/validation/sensitive), outputs, locals, tfvars, thứ tự ưu tiên
- `lab-03-expressions-meta-arguments` — functions, `count` vs `for_each`, conditional, `dynamic`
- `lab-04-data-sources-providers` — data sources, `http`, provider `alias`, multiple configs

**Level 2 — Modules**
- `lab-05-first-module` — module tái sử dụng đầu tiên, input/output contract
- `lab-06-module-composition` — composition, `for_each` trên module, sources/versioning, refactor monolith→modules

**Level 3 — State Mastery (trọng tâm import)**
- `lab-07-terraform-import` — `terraform import` cổ điển trên container tạo thủ công
- `lab-08-import-blocks-codegen` — `import {}` + `-generate-config-out` (1.5+), import hàng loạt
- `lab-09-state-surgery` — `state mv/rm/replace-provider`, `moved {}`/`removed {}`, refactor an toàn
- `lab-10-backends-workspaces-drift` — backends, workspaces, locking, drift & `-refresh-only`, phục hồi state

**Level 4 — Expert**
- `lab-11-validation-conditions` — `validation`, `precondition`/`postcondition`, `check {}`
- `lab-12-testing-lifecycle` — `terraform test` (.tftest.hcl), `replace_triggered_by`, `terraform_data`, `ephemeral`
- `lab-13-policy-cicd` — Policy as Code (OPA/Conftest trên plan JSON) + pipeline CI/CD gating
- `lab-14-capstone-platform` — mini-platform đa module: import + test + policy + drift, chấm theo rubric

## 5. Cấu trúc mỗi lab

```
lab-NN-topic/
├── README.md      # ĐỀ: mục tiêu học, bối cảnh, yêu cầu, tiêu chí pass (đo được), thời lượng
├── starter/       # khung khởi đầu có TODO (người học điền)
├── solution/      # lời giải tham chiếu chuẩn (fmt sạch, validate pass, idiomatic)
├── verify.sh      # script chấm tự động (assert qua terraform/docker/jq)
└── HINTS.md       # gợi ý theo bậc (bung dần, tránh lộ đáp án ngay)
```

## 6. Chuẩn chất lượng (mọi lab phải đạt)

1. Mục tiêu học rõ ràng, đo được.
2. Bối cảnh thực tế (kịch bản như đời thật).
3. `solution/` phải `terraform fmt -check` sạch và `terraform validate` pass.
4. Không dùng cú pháp deprecated; tránh anti-pattern (provisioner trừ khi dạy chính nó; không hardcode secret).
5. `verify.sh`: `set -euo pipefail`, kiểm tra bằng `terraform state list`, `terraform show -json | jq`,
   hoặc `docker inspect`; trả exit code 0/1 và in PASS/FAIL rõ ràng.
6. Mỗi README có mục **"Đào sâu (expert)"** giải thích "vì sao" + cạm bẫy thường gặp.
7. HINTS có 3 bậc: nudge → hướng đi → gần đáp án.

## 7. Quy trình build

Foundation (README/PREREQUISITES/RUBRIC/scripts/CONVENTIONS) viết trước thủ công để đồng nhất, sau đó
dùng nhiều sub-agent song song soạn từng level theo `docs/CONVENTIONS.md`, cuối cùng review hợp nhất +
một lượt code-review trước khi giao.

## 8. Phạm vi loại trừ (YAGNI)

- Không bắt buộc cloud thật (AWS/Azure/GCP) — chỉ nhắc khái niệm khi cần.
- CDKTF / Terragrunt / provider development sâu: chỉ nhắc tham khảo, không phải lab bắt buộc.
