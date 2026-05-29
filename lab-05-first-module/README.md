# Lab 05 — First Module

> **Cấp độ:** Trung cấp
> **Thời lượng dự kiến:** ~60 phút
> **Yêu cầu trước:** Lab 00, 01, 02, 03, 04.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Cấu trúc** một Terraform module chuẩn: `versions.tf` (chỉ `required_providers`),
   `variables.tf`, `main.tf`, `outputs.tf`, `README.md`.
2. **Thiết kế input/output contract** rõ ràng: type constraint, default hợp lý,
   `validation`, output có `description`, `sensitive` khi cần.
3. **Gọi module cục bộ** qua relative path (`./modules/<name>`), gọi nhiều lần với
   cấu hình khác nhau.
4. **Không** đặt `provider {}` block bên trong module con — hiểu vì sao đó là
   best practice (không phải "kiểu gì cũng được").
5. **Forward output** từ module ra root, dùng `try()` cho output có thể null.
6. **Phân biệt** `terraform get` và `terraform init` — module loading thực sự xảy ra
   khi nào.

## 🌐 Bối cảnh

Lab 02 và 03 dạy bạn cách viết 1 service nginx có cấu hình "chuẩn": image + container,
labels, optional log volume, optional custom index.html. Bây giờ team có **nhiều** service
cùng pattern đó (api, frontend, admin, ...). Copy-paste resource block là **kỹ thuật nợ**.

Nhiệm vụ: **tách "1 service nginx có cấu hình chuẩn" thành module** `web_service` đặt trong
`./modules/web_service`. Root config gọi module 2 lần để dựng `api` (port 8093, mặc định)
và `frontend` (port 8094, có log volume, có index.html tuỳ biến).

## 📋 Yêu cầu cụ thể

### Module `./modules/web_service/`

- [ ] `versions.tf` — KHAI BÁO `required_providers` cho `docker` + `local`. **KHÔNG** có
      `provider "docker" {}` block.
- [ ] `variables.tf` với:
  - `name` — `string`, bắt buộc, **validation**: regex `^[a-z0-9-]+$` và length `[2, 32]`.
  - `image` — `string`, bắt buộc, **validation** chặn tag `:latest`.
  - `external_port` — `number`, bắt buộc, **validation** `1 <= x <= 65535`.
  - `labels` — `map(string)`, default `{}`.
  - `index_content` — `string`, default `null` (optional custom HTML).
  - `enable_log_volume` — `bool`, default `false`.
- [ ] `main.tf`:
  - `docker_image.this` từ `var.image`.
  - `docker_container.this` tên `"tflab-05-${var.name}"`, port `external = var.external_port`.
  - `local_file.index` chỉ tạo khi `var.index_content != null` (`count = 0/1`).
  - `docker_volume.logs` chỉ tạo khi `var.enable_log_volume == true` (`count = 0/1`).
  - `dynamic "volumes"` mount index file vào `/usr/share/nginx/html/index.html`.
  - `dynamic "volumes"` mount log volume vào `/var/log/nginx`.
  - `dynamic "labels"` merge `var.labels` với `{ managed_by = "terraform", service = var.name }`.
- [ ] `outputs.tf`:
  - `container_id` — id của container.
  - `name` — tên container.
  - `url` — `"http://localhost:${var.external_port}"`.
  - `volume_name` — `try(docker_volume.logs[0].name, null)`.
- [ ] `README.md` — bảng inputs/outputs + ví dụ sử dụng (Markdown).

### Root module (cùng thư mục `starter/`)

- [ ] `versions.tf` — đầy đủ `required_providers`, có `provider "docker" {}`.
- [ ] `main.tf`:
  - `random_id.build` (4 bytes) — dùng làm "build id" stamp vào HTML frontend.
  - `module "api"`: `name = "api"`, `external_port = 8093`, labels `{ role = "backend", tier = "api" }`.
  - `module "frontend"`: `name = "frontend"`, `external_port = 8094`,
    `enable_log_volume = true`, `index_content = templatefile(...)` với
    `{ title, build_id }`, labels `{ role = "frontend", tier = "web" }`.
- [ ] `outputs.tf`:
  - `urls` — map `{ api = module.api.url, frontend = module.frontend.url }`.
  - `container_names` — map các tên container.
  - `frontend_volume` — `module.frontend.volume_name`.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể `verify.sh` kiểm tra:

- `terraform fmt -check -recursive` (bao gồm cả `modules/`) sạch.
- `terraform validate` ở root pass.
- Module có đủ 5 file (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `README.md`).
- Module **KHÔNG** chứa `provider "..."` block.
- Module validate được **độc lập** (`cd modules/web_service && terraform init -backend=false && terraform validate`).
- `terraform state list` chứa `module.api.*` và `module.frontend.*`.
- `module.frontend.docker_volume.logs[0]` tồn tại; `module.api.docker_volume.logs` KHÔNG tồn tại.
- `module.frontend.local_file.index[0]` tồn tại.
- 2 container `tflab-05-api` và `tflab-05-frontend` đang chạy.
- `docker volume ls` có `tflab-05-frontend-logs`.
- `curl http://localhost:8094` trả về content có chứa `tflab-05 Frontend` (HTML tuỳ biến).
- `terraform output frontend_volume` = `tflab-05-frontend-logs`.
- `terraform plan -detailed-exitcode` lần 2 → exit 0 (no changes).

## 🧭 Hướng dẫn làm

```bash
cd starter

# Bước 1: hoàn thiện module trước (đây là phần làm chính).
$EDITOR modules/web_service/variables.tf   # TODO V1..V5
$EDITOR modules/web_service/main.tf        # TODO L1, M1..M5
$EDITOR modules/web_service/outputs.tf     # TODO O1

# Bước 2: hoàn thiện root.
$EDITOR main.tf                            # TODO M1 (module "frontend")
$EDITOR outputs.tf                         # TODO O1..O3

# Bước 3: init + apply.
terraform init                             # init cũng chạy `terraform get` cho module local
terraform plan
terraform apply

# Kiểm tra
terraform output urls | jq .
curl -s http://localhost:8094 | head -10
docker volume ls | grep tflab-05

# Idempotency
terraform plan                             # phải báo "No changes"

# Verify
cd ..
bash verify.sh

# Dọn dẹp
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert)

### Vì sao KHÔNG đặt `provider {}` block trong module con?

Bạn có thể nghĩ "đặt cho gọn, module tự khai báo provider của nó". Đây là cái bẫy.
Khi `provider {}` nằm trong module con, Terraform khoá module vào provider đó. Kéo theo:

1. **Không destroy được sạch khi xoá module.** Module bị xoá khỏi config → provider config
   của nó cũng biến mất, nhưng state vẫn còn resource đang dùng provider đó. Terraform báo
   "Provider configuration not present" và refuse plan.
2. **Không gọi module nhiều lần với provider khác nhau.** Mỗi instance của module sẽ "đẻ"
   thêm provider config — `terraform.tfstate` lộn xộn.
3. **Khó test/replace provider.** `terraform state replace-provider` (lab 09) không chạy
   được vì binding rối.

**Quy tắc:** module con khai báo `required_providers` (source + version) để pin, nhưng
**configuration** (host, region, credentials) là việc của **root**. Khi cần alias, root
truyền tường minh:

```hcl
module "east" {
  source    = "./modules/svc"
  providers = { docker = docker.east }     # explicit pass
}
```

Lab 06 sẽ thực hành pattern này (`configuration_aliases`).

### `terraform get` vs `terraform init`

- `terraform get` chỉ download/refresh module source (clone git, copy local path).
- `terraform init` chạy `get` **rồi** init backend + install provider plugin.

Trong workflow bình thường bạn chỉ dùng `init`. `get` hữu ích khi: đổi `source = ` của module
sang phiên bản mới mà chưa muốn re-init provider — nhanh hơn.

### Module versioning — local vs git vs registry

| Source | Cú pháp | Khi nào dùng |
|--------|---------|--------------|
| Local path | `source = "./modules/x"` | Trong cùng repo; vòng đời dev nhanh |
| Git | `source = "git::https://github.com/org/mod.git//path?ref=v1.2.0"` | Chia sẻ giữa repo; pin bằng `?ref=` |
| Registry | `source = "terraform-aws-modules/vpc/aws"`, `version = "~> 5.0"` | Module public/private registry; có `version` constraint |

**Quy tắc pin:** với git, **luôn** dùng `?ref=<tag>` (KHÔNG `?ref=main` — sẽ drift bất ngờ).
Với registry, dùng `version = "~> X.Y"` để cho phép patch update mà chặn breaking.

### Output contract: `sensitive` lan truyền

Nếu module có `output "x" { value = random_password.y.result }` mà KHÔNG đánh dấu
`sensitive = true`, Terraform sẽ báo lỗi "Output refers to sensitive value". Phải mark
sensitive **dọc theo chain** từ resource → module output → root output. Quên 1 mắt xích là
giá trị lộ ra `terraform output`. Lab này không có sensitive output, nhưng nhớ quy tắc cho
production.

### `try()` cho output có thể null

Khi resource dùng `count = X ? 1 : 0`, index `[0]` không tồn tại khi `count = 0`. Output
sẽ lỗi "Invalid index" nếu reference trực tiếp. Pattern chuẩn:

```hcl
output "volume_name" {
  value = try(docker_volume.logs[0].name, null)
}
```

`null` là "absent value" canonical trong Terraform — caller dễ check bằng `== null`.

### Cạm bẫy thường gặp

1. **Đường dẫn tuyệt đối trong `source`.** `source = "/Users/me/modules/x"` → ai khác clone
   repo về sẽ không chạy được. RUBRIC trừ 10 điểm (CONVENTIONS §8).
2. **Module không có README.** RUBRIC trừ 5 điểm. README là **một phần của contract**.
3. **Validation trong module variable nhưng error message chung.** Phải chỉ rõ giá trị sai,
   ví dụ `"got '${var.name}'"`.
4. **`for_each` trên `count`-based resource bên trong module.** Module gọi 2 lần qua
   `for_each` ở root → mỗi instance ổn định; bên trong module dùng `count` cho resource
   conditional là OK (count = 0/1), nhưng KHÔNG dùng `count` để "đếm replicas".
5. **Quên `path.module` cho file path.** `filename = "rendered/x.html"` resolve theo working
   dir của root, KHÔNG phải module. Luôn `"${path.module}/rendered/x.html"`.

### Docs tham khảo

- Modules tổng quan: <https://developer.hashicorp.com/terraform/language/modules>
- Module sources: <https://developer.hashicorp.com/terraform/language/modules/sources>
- Provider configuration trong modules: <https://developer.hashicorp.com/terraform/language/modules/develop/providers>
- Module composition: <https://developer.hashicorp.com/terraform/language/modules/develop/composition>
- `terraform-docs`: <https://terraform-docs.io/>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
