# tflab — Bộ lab Terraform Cơ bản → Expert

> Khoá thực hành Terraform 15 bài (00–14) đi từ vòng đời `init/plan/apply` đầu tiên đến **import
> state**, **state surgery**, **native testing**, **policy-as-code**, và một dự án capstone tổng
> hợp đạt chuẩn expert. Toàn bộ chạy bằng **Docker** + **local providers**, không cần cloud, không
> tốn chi phí.

## Lộ trình

| Lab | Cấp độ | Chủ đề | Thời lượng |
|-----|--------|--------|------------|
| 00 | Cơ bản | Setup & foundations — vòng đời TF, config đầu tiên | 30' |
| 01 | Cơ bản | Resources, dependency ngầm/tường minh, đọc state | 45' |
| 02 | Trung cấp | Variables (validation, sensitive), outputs, locals, tfvars | 45' |
| 03 | Trung cấp | Expressions & functions, `count` vs `for_each`, `dynamic` | 60' |
| 04 | Trung cấp | Data sources, `http`, provider `alias` & multi-config | 45' |
| 05 | Trung cấp | Viết module tái sử dụng đầu tiên | 60' |
| 06 | Nâng cao | Module composition, `for_each` modules, refactor monolith→modules | 75' |
| 07 | Nâng cao | `terraform import` cổ điển trên container Docker | 60' |
| 08 | Nâng cao | `import {}` blocks + `-generate-config-out` (bulk import) | 75' |
| 09 | Nâng cao | State surgery: `state mv/rm/replace-provider`, `moved/removed` | 90' |
| 10 | Nâng cao | Backends, workspaces, locking, drift, refresh-only | 75' |
| 11 | Expert | `validation`, `precondition`/`postcondition`, `check {}` | 60' |
| 12 | Expert | `terraform test`, `replace_triggered_by`, `terraform_data`, `ephemeral` | 90' |
| 13 | Expert | Policy as Code (OPA/Conftest) + CI/CD gating | 75' |
| 14 | **Capstone** | Mini-platform đa module: import + test + policy + drift | 2–3h |

## Cách bắt đầu

```bash
# 1. Kiểm tra môi trường
bash scripts/check-env.sh

# 2. Đi vào lab đầu tiên
cd lab-00-setup-foundations
cat README.md

# 3. Làm trong starter/ — đáp án ở solution/ (chỉ mở sau khi bí)
cd starter
# ... sửa code ...
terraform init && terraform plan && terraform apply

# 4. Tự chấm
cd ..
bash verify.sh

# 5. Sang lab tiếp theo
cd ../lab-01-resources-dependencies
```

Muốn chấm toàn bộ một lượt: `bash scripts/grade.sh`.

## Cách dùng cho người dạy / chuyên gia review

- **Đề bài** ở mỗi `lab-NN/README.md`.
- **Lời giải tham chiếu** ở `lab-NN/solution/` — đã `terraform fmt` & `terraform validate` sạch.
- **Tự động chấm** qua `lab-NN/verify.sh` (exit 0 = PASS).
- **Rubric** tổng (cho điểm chất lượng code, không chỉ pass/fail) ở `RUBRIC.md`.
- **Chuẩn soạn lab** ở `docs/CONVENTIONS.md` — dùng để đánh giá tính nhất quán & chất lượng.

## Yêu cầu môi trường

Xem [PREREQUISITES.md](./PREREQUISITES.md) — tóm tắt: Terraform >= 1.9, Docker, jq, (tuỳ chọn)
conftest cho lab 13.

## Cấu trúc repo

```
tflab/
├── README.md
├── PREREQUISITES.md
├── RUBRIC.md
├── docs/
│   ├── CONVENTIONS.md
│   └── superpowers/specs/2026-05-28-terraform-lab-design.md
├── scripts/
│   ├── check-env.sh
│   └── grade.sh
└── lab-00-setup-foundations/
    ├── README.md           # đề bài
    ├── starter/            # khung khởi đầu
    ├── solution/           # lời giải tham chiếu
    ├── verify.sh           # chấm tự động
    └── HINTS.md            # gợi ý 3 bậc
... (15 lab tương tự)
```

## License

Dùng cho mục đích học tập và đào tạo nội bộ.
