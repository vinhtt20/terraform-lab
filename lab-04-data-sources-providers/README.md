# Lab 04 — Data Sources & Providers

> **Cấp độ:** Trung cấp
> **Thời lượng dự kiến:** ~45 phút
> **Yêu cầu trước:** Lab 00, 01, 02, 03.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Phân biệt** *data source* (chỉ đọc, không quản lý lifecycle) và *resource* (quản lý
   lifecycle).
2. **Dùng** 2 data source phổ biến: `docker_registry_image` (lấy digest), `local_file`
   (đọc file trong module).
3. **(Tuỳ chọn)** Dùng `http` data source để gọi endpoint ngoài — và hiểu tại sao điều đó
   nguy hiểm với pipeline CI/CD.
4. **Cấu hình** **provider alias** cho 2 "vùng" giả lập (`east`, `west`) trên cùng Docker
   daemon — học cú pháp multi-provider cho khi cần thật (multi-region/multi-account cloud).
5. **Chỉ định** rõ provider cho từng resource qua meta-argument `provider = docker.east`.
6. **Pin image bằng digest** (`@sha256:...`) thay vì tag — best practice production.

## 🌐 Bối cảnh

Đội bạn đang lên blueprint cho hệ multi-region: cùng image, deploy ở 2 vùng (`east`, `west`).
Trên máy dev, bạn chỉ có 1 Docker daemon, nhưng cần **đúng cú pháp** để khi chuyển sang
AWS/GCP, đổi mỗi provider config là chạy. Yêu cầu kèm:

- Lấy **digest** mới nhất của `nginx:1.27-alpine` (qua data source) để pin cứng — không để
  tag tự "drift".
- Đọc file `motd.txt` trong module qua data source `local_file` và hash SHA-256 đưa vào label
  container.

## 📋 Yêu cầu cụ thể

- [ ] `versions.tf`: `kreuzwerker/docker ~> 3.0`, `hashicorp/local ~> 2.5`,
      `hashicorp/http ~> 3.4`.
- [ ] 3 cấu hình provider docker: default + alias `east` + alias `west`. Cả 3 cùng socket
      (dev local).
- [ ] `variables.tf`: `enable_geoip` (`bool`, default `false`).
- [ ] Data sources:
  - `docker_registry_image.nginx` đọc `nginx:1.27-alpine`.
  - `local_file.motd` đọc `${path.module}/files/motd.txt`.
  - `http.geoip` chỉ tạo khi `var.enable_geoip` (URL `https://ipinfo.io/json`, request_timeout_ms).
- [ ] `files/motd.txt` chứa chuỗi `Welcome to tflab-04` (kèm newline).
- [ ] Resource:
  - `docker_image.east` & `docker_image.west` — `name = data.docker_registry_image.nginx.name`
    (digest-pinned format), mỗi cái dùng `provider = docker.east|west`.
  - `docker_container.east` (`tflab-04-east`, port 8090:80) và `docker_container.west`
    (`tflab-04-west`, port 8091:80), mỗi cái `provider = docker.east|west`, labels gồm
    `motd_sha256 = substr(sha256(data.local_file.motd.content), 0, 16)`.
- [ ] Outputs:
  - `digest` — hash bắt đầu bằng `sha256:`.
  - `east_url` — `http://localhost:8090`.
  - `west_url` — `http://localhost:8091`.
  - `motd_sha256` — chuỗi hex (full).
  - `geoip` — sensitive, value = `try(data.http.geoip[0].response_body, null)`.
- [ ] `terraform fmt -check -recursive` sạch, `terraform validate` exit 0.
- [ ] `terraform plan` lần 2 báo `No changes`.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể kiểm tra:

- `terraform fmt`, `terraform validate` pass.
- State có `data.docker_registry_image.nginx`, `data.local_file.motd`,
  `docker_image.east|west`, `docker_container.east|west`.
- Output `digest` khớp regex `^sha256:[a-f0-9]{64}$`.
- 2 container `tflab-04-east|west` đang chạy.
- `terraform plan -detailed-exitcode` lần 2 = 0.

## 🧭 Hướng dẫn làm

```bash
cd starter
# Đọc TODO trong main.tf, variables.tf, outputs.tf.

terraform init
terraform plan       # lưu ý: data source CHẠY ở plan/refresh — cần network để fetch digest.
terraform apply

# Kiểm tra digest và URLs
terraform output digest
terraform output east_url west_url

# Cross-check
docker inspect tflab-04-east | jq '.[0].Image'
curl -s http://localhost:8090 | head -1

# Idempotency
terraform plan       # phải báo No changes (digest đã lưu trong state)

# Verify
cd ..
bash verify.sh

# Bật geoip (cần Internet) — chỉ thử:
# terraform plan -var enable_geoip=true

# Dọn dẹp
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert)

### Data source vs Resource

| | Data source | Resource |
|---|---|---|
| Đọc | ✅ | ✅ (qua state) |
| Tạo/Xoá | ❌ | ✅ |
| Khi nào chạy | mỗi plan/refresh | apply (create), refresh (update state) |
| Cú pháp ref | `data.<type>.<name>.<attr>` | `<type>.<name>.<attr>` |
| Idempotent | có (giá trị có thể đổi nếu source bên ngoài đổi) | có (state tracking) |

Quy tắc: chỉ dùng data source cho dữ liệu bạn **không quản lý**. Đừng dùng data source để
"đọc lại thứ mình mới tạo" — Terraform có thể chạy data source trước resource trong plan
(cycle), hoặc dữ liệu chưa "thấy" được.

### Provider alias — khi nào cần?

```hcl
provider "docker" {}                                  # default
provider "docker" { alias = "east"  host = "..." }    # multi-region
provider "docker" { alias = "west"  host = "..." }
```

Khi nào dùng:
- **Multi-region cloud** (AWS `us-east-1` vs `us-west-2`).
- **Multi-account** (provider `aws.prod` vs `aws.dev`).
- **Mix versions** (provider khác version cho legacy resource — hiếm).

Cách chỉ định: `resource "..." "..." { provider = docker.east }`. Trong module: caller
truyền qua `providers = { docker = docker.east }`.

**Anti-pattern:** đặt provider block **bên trong module** với alias hardcode → module không
tái sử dụng được. Luôn để caller truyền provider vào.

### Pin image bằng digest

```hcl
data "docker_registry_image" "nginx" {
  name = "nginx:1.27-alpine"
}

resource "docker_image" "nginx" {
  name = data.docker_registry_image.nginx.name
  # data.docker_registry_image.nginx.name có dạng "nginx:1.27-alpine@sha256:abcdef..."
}
```

So sánh:

| | Pin theo tag | Pin theo digest |
|---|---|---|
| Reproducible | ❌ (tag bị "ép" lên) | ✅ (digest immutable) |
| Update workflow | tự cập nhật khi pull | phải sửa Terraform để bump digest |
| Hợp với supply chain security | yếu | mạnh (kèm signature verification) |
| Lab/dev | OK | hơi phiền |
| Production | KHÔNG đủ | chuẩn |

### `http` data source — cẩn thận với CI/CD

`http` data source gọi network mỗi lần plan. Hệ quả:

- **CI flaky:** endpoint xuống → plan fail → bạn không apply được fix.
- **Quota/rate-limit:** endpoint giới hạn calls → CI gặp 429.
- **Provider state poisoning:** nếu data source trả khác mỗi plan, state diff liên tục.

Khuyến nghị: **fetch data ngoài Terraform** (ở build step), pass vào qua `-var`/`*.tfvars`.
Lab này để mặc định `enable_geoip = false` để pipeline không phụ thuộc Internet.

### `terraform providers` để xem provider graph

```bash
terraform providers
# In ra cây phụ thuộc provider, hữu ích khi debug "tại sao module này yêu cầu provider X".
```

### Cạm bẫy thường gặp

1. **Data source dùng cho thứ bạn mới tạo:** dependency loop hoặc dữ liệu chưa sẵn sàng.
   Dùng output của resource trực tiếp.
2. **`http` data source ở `default = true`:** bom hẹn giờ trong CI.
3. **Quên `provider = docker.east` ở resource khi đã định alias:** Terraform dùng default
   provider → resource tạo nhầm chỗ. Tệ nhất: chỉ phát hiện ở production.
4. **Pin digest rồi quên cập nhật:** bản vá security không bao giờ vào → cũng tệ. Dùng
   automation (Renovate, Dependabot) để bump.

### Docs tham khảo

- Data sources: <https://developer.hashicorp.com/terraform/language/data-sources>
- Provider configuration: <https://developer.hashicorp.com/terraform/language/providers/configuration>
- Provider alias: <https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-configurations>
- `docker_registry_image`: <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/data-sources/registry_image>
- `http` data source: <https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
