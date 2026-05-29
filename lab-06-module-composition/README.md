# Lab 06 — Module Composition

> **Cấp độ:** Nâng cao
> **Thời lượng dự kiến:** ~75 phút
> **Yêu cầu trước:** Lab 00–05 (đặc biệt Lab 05).

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Refactor** một monolith Terraform (1 network + 3 container inline) thành 2 module
   thiết kế hợp lý: `network` và `service`.
2. **Dùng `for_each` trên module** để tạo N module instance từ 1 map cấu hình.
3. **Compose** module với module: `module "network"` cung cấp `name` → input của
   `module "service"` (dataflow rõ ràng giữa các module).
4. **Truyền provider alias vào module** qua `providers = { docker.target = docker.east }`,
   khai báo `configuration_aliases` ở module con.
5. **Hiểu anti-pattern**: `for_each` trên module + provider alias **động** theo
   `each.value` là KHÔNG được hỗ trợ — phải tách thành nhiều module call (1/region).
6. **Module sources**: local path hôm nay; biết cú pháp git/registry cho mai sau.
7. **Validate module độc lập** (cho module không cần `configuration_aliases`):
   `cd modules/network && terraform init -backend=false && terraform validate`.

## 🌐 Bối cảnh

Sau lab 05 bạn đã có module `web_service` đơn giản. Bây giờ team scale lên: 1 "mini-platform"
gồm 1 shared network + 3 service (`web`, `api`, `worker`), mỗi service deploy vào 1 "region"
(`east` hoặc `west`) — mô phỏng multi-region bằng Docker provider alias.

Code hiện tại là **monolith** trong `starter/main.tf`: 1 `docker_network` + 3 `docker_container`
copy-paste. Cùng team đề nghị **refactor sang module** vì sắp scale lên 10 service.

## 📋 Yêu cầu cụ thể

### Module `./modules/network/`

- [ ] `versions.tf` — chỉ `required_providers { docker = ... }`, KHÔNG provider block,
      KHÔNG `configuration_aliases` (network là region-agnostic).
- [ ] `variables.tf`:
  - `name` — `string`, validation regex `^[a-z0-9][a-z0-9_-]*$`.
  - `labels` — `map(string)`, default `{}`.
- [ ] `main.tf` — 1 `docker_network` (driver `bridge`), labels merged
      `{ managed_by = "terraform", component = "network" }` + `var.labels`, dynamic labels block.
- [ ] `outputs.tf` — `id`, `name`.
- [ ] `README.md` — bảng inputs/outputs.

### Module `./modules/service/`

- [ ] `versions.tf` — `required_providers { docker = { source, version, configuration_aliases = [docker.target] } }`.
- [ ] `variables.tf`:
  - `name`, `image`, `external_port`, `network_name` — đều validation phù hợp.
  - `replicas` — `number`, default `1`, validation `1..3`.
  - `labels` — `map(string)`, default `{}`.
  - `healthcheck` — `object({ enabled = bool, interval = string })`,
                    default `{ enabled = true, interval = "10s" }`.
- [ ] `main.tf`:
  - `docker_image.this` với `provider = docker.target`.
  - `docker_container.this` với `provider = docker.target` và
    `for_each = toset([for i in range(var.replicas) : tostring(i)])`.
  - `networks_advanced { name = var.network_name, aliases = [var.name] }`.
  - Port `external = var.external_port + tonumber(each.key)` (tránh collision).
  - `dynamic "healthcheck"` chỉ render khi `var.healthcheck.enabled == true`.
  - `dynamic "labels"` từ map merged.
- [ ] `outputs.tf` — `container_names` (list), `urls` (list), `image_id`, `replicas`.
- [ ] `README.md` — bảng inputs/outputs + ví dụ với `providers = {}`.

### Root (`starter/`)

- [ ] `versions.tf` — `required_providers` + 3 `provider "docker"`: default, `alias = "east"`,
      `alias = "west"`.
- [ ] `main.tf`:
  - `locals.services` map có đúng 3 entry với schema
    `{ region = "east"|"west", image = string, external_port = number, replicas = number }`:
    - `web`    — `region=east`, `port=8100`, `replicas=2` (chiếm 8100-8101).
    - `api`    — `region=west`, `port=8102`, `replicas=1`.
    - `worker` — `region=east`, `port=8103`, `replicas=1`.
  - `locals.services_east`, `locals.services_west` — filter theo region.
  - `module "network"` — name = `tflab-06-net`.
  - `module "service_east"` — `for_each = local.services_east`,
    `providers = { docker.target = docker.east }`, truyền `module.network.name`.
  - `module "service_west"` — tương tự, `docker.west`.
- [ ] `outputs.tf`:
  - `network_id`, `network_name` — từ `module.network`.
  - `services_east` — `{ for k, m in module.service_east : k => m.urls }`.
  - `services_west` — tương tự.
  - `container_names` — flat list, concat east + west.
- [ ] Monolith ở `starter/main.tf` được XOÁ HẾT — chỉ còn `locals` + 3 module call.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Kiểm tra cụ thể:

- `terraform fmt -check -recursive` sạch.
- `terraform validate` (root) pass.
- 2 module có đủ 5 file mỗi cái (versions, variables, main, outputs, README).
- KHÔNG module nào có `provider "..."` block.
- `modules/service/versions.tf` có `configuration_aliases`.
- `cd modules/network && terraform init -backend=false && terraform validate` pass.
- `terraform state list` chứa: `module.network.docker_network.*`,
  `module.service_east["web"].docker_container.this["0"]`, `..["1"]`,
  `module.service_east["worker"].docker_container.this["0"]`,
  `module.service_west["api"].docker_container.this["0"]`.
- `terraform state list` KHÔNG còn `docker_*` ở root.
- 4 container `tflab-06-{web-0, web-1, api-0, worker-0}` đang chạy.
- Docker network có 4 container attached.
- Output `services_east` keys = `web,worker`; `services_west` = `api`.
- `terraform plan -detailed-exitcode` lần 2 → exit 0.

## 🧭 Hướng dẫn làm

```bash
cd starter
# Đọc monolith trong main.tf — đây là điểm BẮT ĐẦU.

# Bước 1: tạo module network.
mkdir -p modules/network
$EDITOR modules/network/{versions,variables,main,outputs,README.md}.tf

# Bước 2: tạo module service. Chú ý configuration_aliases.
mkdir -p modules/service
$EDITOR modules/service/{versions,variables,main,outputs,README.md}.tf

# Bước 3: refactor root — xoá hết docker_* inline, thay bằng module call.
$EDITOR main.tf outputs.tf versions.tf

# Bước 4: validate độc lập module network (best practice).
(cd modules/network && terraform init -backend=false && terraform validate)

# Bước 5: init + apply ở root.
terraform init      # tải provider + lock module
terraform plan
terraform apply

# Idempotency
terraform plan      # phải báo "No changes"

cd ..
bash verify.sh

# Dọn dẹp
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert)

### `configuration_aliases` — vì sao cần, khi nào dùng

Khi module con cần dùng **nhiều provider config khác nhau** (alias) do root cung cấp, module
phải khai báo trước trong `required_providers`:

```hcl
required_providers {
  docker = {
    source                = "kreuzwerker/docker"
    version               = "~> 3.0"
    configuration_aliases = [docker.target]    # ← module sẽ dùng provider "docker.target"
  }
}
```

Bên trong module, resource viết `provider = docker.target`. Root truyền alias thực vào:

```hcl
module "x" {
  source = "./modules/service"
  providers = {
    docker.target = docker.east   # bind alias-trong-module → alias-ở-root
  }
}
```

**Nếu thiếu `configuration_aliases`**, root sẽ báo lỗi: "the child module does not require an
additional configuration for provider docker, with the alias 'target'".

Module **không cần** `configuration_aliases` khi nó chỉ dùng provider mặc định (như
`modules/network/` của lab này).

### Anti-pattern: `for_each` trên module + alias **động**

Mong muốn (NOT supported):

```hcl
# ❌ KHÔNG chạy được.
module "service" {
  for_each = local.services
  source   = "./modules/service"
  providers = {
    docker.target = docker[each.value.region]   # ← lỗi: providers PHẢI là static
  }
  ...
}
```

Terraform yêu cầu khối `providers = {}` được biết **lúc graph build** (trước plan). Mỗi instance
của `for_each` sẽ thừa hưởng cùng 1 mapping providers. Không có cú pháp "providers theo each.value".

**Workaround chuẩn:** tách thành nhiều module call, mỗi cái nhắm 1 alias:

```hcl
module "service_east" {
  for_each = { for k, v in local.services : k => v if v.region == "east" }
  source   = "./modules/service"
  providers = { docker.target = docker.east }   # ← static, OK
  # ...
}

module "service_west" {
  for_each = { for k, v in local.services : k => v if v.region == "west" }
  source   = "./modules/service"
  providers = { docker.target = docker.west }
  # ...
}
```

Đây không phải hack — đây là pattern documented trong HashiCorp docs.

### Module composition: network → service

Có 2 cách compose:

1. **Flat (root composes):** root tạo network, root gọi service truyền `network.name`. Đây là
   lab này. Dataflow rõ ràng — đọc root là biết hết.
2. **Nested (parent module composes):** module `platform` bên trong gọi cả 2. Root chỉ gọi
   `platform`. Tốt khi muốn đóng gói "1-click platform" cho team khác dùng, **nhưng** che mất
   dataflow — khó debug.

**Mặc định chọn flat**; chuyển sang nested khi đã thật sự cần đóng gói.

### Khi nào KHÔNG nên tách thành module?

Heuristic: **1 module = 1 trách nhiệm + ít nhất 2 chỗ gọi.**

- Nếu module chỉ có 1 resource và 1 chỗ gọi → đừng tách. Refactor không tăng giá trị mà tăng
  số file phải đọc.
- Nếu module có nhiều resource nhưng chỉ 1 chỗ gọi → giữ inline, dùng `locals` để gom logic.
- Tách khi: (a) bắt đầu copy-paste lần 2 hoặc (b) cần config tách biệt cho từng instance.

### Module sources: local vs git vs registry

| Pattern | Khi dùng | Cú pháp |
|---------|----------|---------|
| Local path | Cùng repo, dev nhanh | `source = "./modules/x"` |
| Git, pinned tag | Chia sẻ giữa team/repo | `source = "git::https://example.com/x.git//path?ref=v1.2.0"` |
| Registry (public/private) | Reuse rộng, có versioning gắn liền | `source = "ns/name/aws"`, `version = "~> 2.0"` |

**Quy tắc:** với git, **bắt buộc** `?ref=<tag>` (KHÔNG `?ref=main`). Lý do: 6 tháng sau commit
chính nào đó breaking, `terraform init` của bạn sẽ fail không thể reproduce.

### Refactor monolith → module: vấn đề state

Khi đổi từ `docker_network.platform` (root resource) thành `module.network.docker_network.this`,
Terraform thấy:
- Resource cũ ở root **biến mất** → DESTROY.
- Resource mới trong module **xuất hiện** → CREATE.

→ Downtime cho network. Cách giải đúng: dùng **`moved {}`** block để báo Terraform "nó cùng resource,
chỉ đổi địa chỉ":

```hcl
moved {
  from = docker_network.platform
  to   = module.network.docker_network.this
}
```

Lab 09 sẽ dạy `moved` chi tiết. Trong lab này bạn có thể **destroy + apply lại** vì là môi
trường lab; trong production thì `moved` là bắt buộc.

### `terraform_data` — giới thiệu

Khi cần một "anchor" trong state để bám lifecycle (như `null_resource` xưa) — dùng
`terraform_data` (built-in, không cần provider null). Pattern:

```hcl
resource "terraform_data" "config_version" {
  input = jsonencode({ version = var.version, services = keys(var.services) })

  # Trigger replace của X khi config_version thay đổi.
  # X bên dưới sẽ tham chiếu terraform_data.config_version.id qua replace_triggered_by.
}
```

Lab 12 sẽ đào sâu `terraform_data` + `replace_triggered_by` + `ephemeral`.

### Cạm bẫy thường gặp

1. **Port collision khi `replicas > 1`.** Mỗi replica phải dùng port riêng. Module phải tính
   `external_port + idx` thay vì gắn cứng — nếu không, replica 2 sẽ "bind: address already in use".
2. **Quên `providers = {}` ở module có `configuration_aliases`.** Lỗi rất sớm: "The child module
   requires an additional configuration for provider docker.target".
3. **Đặt `provider "docker" { alias = "east" }` BÊN TRONG module.** Anti-pattern — module sẽ
   không reusable. Provider config phải ở root.
4. **`for_each` map có key không ổn định.** Nếu key dùng giá trị tính lúc apply (như resource ID),
   Terraform sẽ báo "for_each value depends on resource attributes that cannot be determined until
   apply". Lab này dùng key tĩnh (`"web"`, `"api"`, `"worker"`).
5. **Output module reference `module.x[<key>].output` mà quên `for k, m in module.x : ...`** khi
   module có `for_each`. Reference trực tiếp `module.x.name` sẽ lỗi cú pháp.

### Docs tham khảo

- Module composition: <https://developer.hashicorp.com/terraform/language/modules/develop/composition>
- Module providers: <https://developer.hashicorp.com/terraform/language/modules/develop/providers>
- `configuration_aliases`: <https://developer.hashicorp.com/terraform/language/modules/develop/providers#provider-aliases-within-modules>
- Module sources: <https://developer.hashicorp.com/terraform/language/modules/sources>
- `moved {}`: <https://developer.hashicorp.com/terraform/language/modules/develop/refactoring>
- `terraform_data`: <https://developer.hashicorp.com/terraform/language/resources/terraform-data>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
