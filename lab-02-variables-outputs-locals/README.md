# Lab 02 — Variables, Outputs & Locals

> **Cấp độ:** Trung cấp
> **Thời lượng dự kiến:** ~45 phút
> **Yêu cầu trước:** Đã hoàn thành Lab 00 và Lab 01.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Khai báo** biến với **type constraint** (`string`, `number`, `bool`, `list`, `map`, `object`)
   và **validation** block có error message hữu ích.
2. **Phân biệt** thứ tự ưu tiên của các nguồn cấp giá trị biến (`-var` > `-var-file` >
   `*.auto.tfvars` > `terraform.tfvars` > `TF_VAR_*` > `default`).
3. **Sử dụng** `locals` để tạo giá trị dẫn xuất (derived) — naming, label maps — tránh lặp.
4. **Đánh dấu** biến/output **`sensitive`** và hiểu vì sao chúng VẪN nằm trong state plaintext.
5. **Tạo** một resource `random_password` chỉ khi người dùng KHÔNG truyền sẵn — pattern
   "auto-generate hoặc dùng giá trị truyền vào".
6. **Sinh** file tóm tắt (JSON) bằng `local_file` từ giá trị tính ở `locals`.

## 🌐 Bối cảnh

Đội bạn cần một mẫu Terraform "config-driven" để dựng 1 service nhỏ: vài bản sao container,
nhãn (label) đồng nhất, và mật khẩu admin sinh ngẫu nhiên. Yêu cầu từ lead:

- Image tag KHÔNG được là `latest` (an toàn cho production).
- Tên service phải hợp lệ DNS (a-z, 0-9, dấu `-`).
- Số bản sao trong khoảng 1–5; cổng host trong khoảng 8000–9000.
- Mật khẩu: nếu ops truyền sẵn → dùng nguyên; nếu không → Terraform sinh giúp.
- Ghi tóm tắt cấu hình (KHÔNG bao gồm mật khẩu) ra file JSON để CI khác có thể đọc.

## 📋 Yêu cầu cụ thể

- [ ] `versions.tf` khai báo provider: `kreuzwerker/docker ~> 3.0`,
      `hashicorp/random ~> 3.6`, `hashicorp/local ~> 2.5`.
- [ ] `variables.tf` định nghĩa các biến sau:
  - `image` — `object({ name = string, tag = string })`,
        default `{ name = "nginx", tag = "1.27-alpine" }`;
        **validation** từ chối `tag == "latest"` với error message hữu ích.
  - `service_name` — `string`, default `"demo"`;
        validation: độ dài 3–32, **regex** `^[a-z0-9-]+$`.
  - `replicas` — `number`, default `2`; validation `1 <= x <= 5`.
  - `labels` — `map(string)`, default `{ owner = "team-a", env = "dev" }`.
  - `external_port_base` — `number`, default `8082`;
        validation `8000 <= x <= 9000`.
  - `admin_password` — `string`, **`sensitive = true`**, default `null`.
- [ ] `locals.tf` (hoặc gộp vào `main.tf`):
  - `container_name_prefix = "tflab-02-${var.service_name}"`
  - `merged_labels = merge(var.labels, { managed_by = "terraform" })`
  - `password_effective = coalesce(var.admin_password, try(random_password.admin[0].result, null))`
- [ ] `main.tf`:
  - `random_password.admin` length=20 special=true, chỉ tạo khi `var.admin_password == null`
    (`count = var.admin_password == null ? 1 : 0`).
  - `docker_image.app` với `name = "${var.image.name}:${var.image.tag}"`.
  - `docker_container.app` dùng `for_each = toset([for i in range(var.replicas) : tostring(i)])`,
    tên `"${local.container_name_prefix}-${each.key}"`,
    cổng `external = var.external_port_base + tonumber(each.key)`,
    `labels` qua **`dynamic`** block đọc từ `local.merged_labels`.
  - `local_file.summary` ghi `jsonencode({ names = [...], ports = [...], labels = {...} })`
    ra `${path.module}/summary.json`. **KHÔNG bao gồm password**.
- [ ] `outputs.tf`:
  - `container_names` (list).
  - `ports` (list of number).
  - `password` — **`sensitive = true`**, value = `local.password_effective`.
  - `summary_path` — đường dẫn file summary.
- [ ] `terraform fmt -check -recursive` sạch.
- [ ] `terraform validate` exit 0.
- [ ] Sau `apply`, `terraform plan` lần 2 báo `No changes`.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể `verify.sh` kiểm tra:

- `terraform fmt` sạch, `terraform validate` exit 0.
- `terraform output container_names` chứa các tên khớp pattern `tflab-02-<service>-<index>`.
- Số phần tử output `ports` khớp `replicas`.
- `terraform output password` (không `-json`) in ra `<sensitive>` (đánh dấu đúng).
- File `summary.json` tồn tại, là JSON hợp lệ, có 3 key `names`, `ports`, `labels`.
- `terraform plan -detailed-exitcode` lần 2 trả về exit code 0.

## 🧭 Hướng dẫn làm

```bash
cd starter
# Đọc TODO trong variables.tf, main.tf, outputs.tf — điền lần lượt.

terraform init
terraform plan
terraform apply

# Xem giá trị output
terraform output                      # password sẽ in "<sensitive>"
terraform output -raw password        # đây mới in giá trị thật (đánh dấu sensitive vẫn lộ khi -raw)
cat summary.json | jq .

# Thử override biến qua các kênh khác nhau (xem mục "Đào sâu")
TF_VAR_service_name=hello terraform plan
terraform plan -var 'replicas=3'

# Idempotency
terraform plan         # phải báo "No changes"

# Verify
cd ..
bash verify.sh

# Dọn dẹp
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert)

### Thứ tự ưu tiên của giá trị biến (cao → thấp)

Khi cùng 1 biến được set ở nhiều nơi, Terraform chọn nguồn theo thứ tự sau:

| # | Nguồn | Ghi chú |
|---|-------|---------|
| 1 | `-var` flag trên CLI | Cao nhất — debug ad-hoc |
| 2 | `-var-file=...` flag (theo thứ tự trên CLI, file sau ghi đè file trước) | Dùng cho per-env file |
| 3 | `*.auto.tfvars` / `*.auto.tfvars.json` (lexical order) | Tự load, không cần flag |
| 4 | `terraform.tfvars` / `terraform.tfvars.json` | File mặc định, tự load |
| 5 | Biến môi trường `TF_VAR_<name>` | Tiện cho CI/CD secret |
| 6 | `default` trong `variable {}` | Thấp nhất |

Quy tắc: **không** trộn nguồn cho cùng 1 biến — nếu thấy mình đang phải dùng cùng lúc 3 nguồn
cho 1 biến, có lẽ thiết kế đang sai.

### `sensitive` không = "encrypted"

Đánh dấu `sensitive = true` cho biến/output chỉ làm 2 việc:

1. Ẩn giá trị khỏi output console (`terraform output` in `<sensitive>`).
2. Cấm `terraform plan` in giá trị đó trong diff.

Giá trị **vẫn nằm plaintext trong `terraform.tfstate`**. Mở file ra là đọc được. Đó là lý do
các team production phải dùng **remote backend có encryption-at-rest** (S3 + KMS, Terraform Cloud,
v.v.) — lab 10 sẽ dạy chi tiết. Quy tắc bây giờ: **không commit `terraform.tfstate` vào git**
(đã có trong `.gitignore` của repo).

### `validation` (biến) vs `precondition` (data/resource)

| Thứ | Ở đâu | Khi nào chạy | Dùng cho |
|-----|-------|--------------|----------|
| `validation` | block `variable {}` | Lúc Terraform parse biến (trước plan) | Ràng buộc giá trị **đầu vào** |
| `precondition` | `lifecycle {}` của resource/data | Lúc plan, sau khi đã có giá trị | Khẳng định **giả định** trước khi tạo |
| `postcondition` | `lifecycle {}` của resource/data | Sau khi attribute đã biết | Khẳng định **kết quả** đạt yêu cầu |

Lab 11 sẽ đào sâu `precondition`/`postcondition`/`check {}`. Ở lab này tập trung `validation`
cho biến.

### Cạm bẫy thường gặp

1. **Type lỏng (`any`) hoặc thiếu type.** Mất khả năng bắt lỗi sớm — Terraform vẫn chấp nhận
   nhưng người gọi module phải đoán cấu trúc. Luôn khai báo `type = ...` rõ ràng.
2. **`default = null` mà không xử lý `null` ở consumer.** Dùng `coalesce()`, `try()`, hoặc
   `coalescelist()` để fallback. Trong lab này pattern `coalesce(var.x, try(resource.x[0].y, null))`
   là chuẩn cho "input optional, auto-generate fallback".
3. **`for_each` trên giá trị tính từ resource khác (`unknown at plan time`).** Terraform sẽ
   báo lỗi yêu cầu key biết trước plan. Cách giải: dùng key là **giá trị tĩnh** (string literal,
   `range()`, key của map đã biết).
4. **`validation` error message quá chung chung.** RUBRIC trừ điểm nếu message không chỉ rõ
   giá trị sai. Ví dụ tốt: `"replicas phải nằm trong [1,5], nhận được ${var.replicas}"`.
5. **Output sensitive mà output khác lại reference qua nó không sensitive.** Terraform sẽ báo
   lỗi — phải đánh dấu cả chain sensitive, hoặc dừng reference.

### Docs tham khảo

- Input variables: <https://developer.hashicorp.com/terraform/language/values/variables>
- Variable validation: <https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules>
- Output sensitive: <https://developer.hashicorp.com/terraform/language/values/outputs#sensitive-suppressing-values-in-cli-output>
- Locals: <https://developer.hashicorp.com/terraform/language/values/locals>
- `random_password`: <https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
