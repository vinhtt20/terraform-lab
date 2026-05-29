# Lab 03 — Expressions & Meta-arguments

> **Cấp độ:** Trung cấp
> **Thời lượng dự kiến:** ~60 phút
> **Yêu cầu trước:** Lab 00, 01, 02.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Sử dụng** các nhóm function chính: string (`format`, `lower`, `replace`, `trim`),
   collection (`length`, `merge`, `concat`, `flatten`, `lookup`),
   encoding (`jsonencode`, `jsondecode`),
   filesystem (`file`, `templatefile`, `fileset`),
   date (`formatdate`, `plantimestamp`),
   crypto (`sha256`, `uuid`).
2. **Phân biệt** `count` và `for_each` — khi nào dùng cái nào, ảnh hưởng tới key stability.
3. **Viết** `for` expression (list & map comprehension), `splat` (`[*]`), `conditional` (`? :`).
4. **Dùng** `dynamic` block để render nested block từ giá trị tính lúc plan.
5. **Render** HTML template qua `templatefile()` (cú pháp `${...}` và `%{ for ... }%{ endfor }`).
6. **Hiểu** các meta-argument resource: `count`, `for_each`, `provider`, `depends_on`,
   `lifecycle`.

## 🌐 Bối cảnh

Bạn cần triển khai **N microservice nginx** trên cùng máy local, mỗi service phục vụ một
trang HTML riêng (giả lập dashboard từng nhóm). Mỗi service có cấu hình riêng:

- image (chia sẻ shared image nginx để tiết kiệm).
- cổng external riêng.
- env vars riêng.
- bật/tắt healthcheck.

Toàn bộ cấu hình đến từ 1 biến `map(object({...}))` — thêm service = thêm 1 entry, không
copy-paste resource block.

## 📋 Yêu cầu cụ thể

- [ ] `versions.tf`: provider `kreuzwerker/docker ~> 3.0` và `hashicorp/local ~> 2.5`.
- [ ] `variables.tf` — định nghĩa biến:
  ```hcl
  variable "services" {
    type = map(object({
      image              = string
      external_port      = number
      env                = optional(map(string), {})
      enable_healthcheck = optional(bool, true)
    }))
  }
  ```
  Default có **3 service ví dụ**: `alpha` (port 8083), `bravo` (port 8084), `charlie` (port 8085).
- [ ] `templates/index.html.tftpl` — template HTML in `service name`, `port`, `env vars`,
      `timestamp` (qua `plantimestamp()`).
- [ ] `main.tf`:
  - 1 `docker_image.nginx` chia sẻ (`nginx:1.27-alpine`).
  - `local_file.html` per service — `for_each = var.services`, render `templatefile()`,
    ghi ra `${path.module}/html/${each.key}.html`.
  - `docker_container.app` per service — `for_each = var.services`:
    - tên `tflab-03-${each.key}`
    - mount HTML qua `volumes { host_path = abspath(local_file.html[each.key].filename),
      container_path = "/usr/share/nginx/html/index.html", read_only = true }`
    - `env = [for k, v in each.value.env : "${k}=${v}"]` — dùng **for expression**.
    - `dynamic "healthcheck"` chỉ khi `each.value.enable_healthcheck == true`.
    - `dynamic "labels"` từ map merged labels.
- [ ] `outputs.tf`:
  - `urls` — map của `name → "http://localhost:PORT"`.
  - `service_count` — `length(var.services)`.
  - `created_at` — `plantimestamp()` (sẽ thay đổi mỗi plan; mục đích chỉ demo function).
- [ ] `terraform fmt -check -recursive` sạch.
- [ ] `terraform validate` exit 0.
- [ ] Sau apply, `terraform plan` lần 2 báo `No changes` (chú ý `created_at` qua
      `lifecycle ignore_changes` nếu cần — gợi ý ở HINTS).

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể kiểm tra:

- `terraform fmt -check`, `terraform validate` pass.
- State chứa đủ `docker_container.app["alpha"|"bravo"|"charlie"]`.
- HTML file rendered ra cho từng service.
- `terraform output urls` là map 3 entry, mỗi value chứa `http://localhost:<port>`.
- (nếu docker đang chạy) `curl http://localhost:8083` trả về content có chứa tên service.
- `terraform plan -detailed-exitcode` lần 2 = 0 (no changes).

## 🧭 Hướng dẫn làm

```bash
cd starter
# Đọc TODO trong variables.tf, main.tf, outputs.tf, templates/index.html.tftpl.

terraform init
terraform plan
terraform apply

# Kiểm tra
terraform output urls | jq .
curl -s http://localhost:8083 | head -20

# Thử thêm 1 service: copy block alpha trong terraform.tfvars (example) thành "delta" port 8086
# rồi `terraform plan` — phải thấy "1 to add, 0 to change, 0 to destroy".

# Idempotency
terraform plan

# Verify
cd ..
bash verify.sh

# Dọn dẹp
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert)

### `count` vs `for_each` — chọn cái nào?

| Tiêu chí | `count` | `for_each` |
|----------|---------|------------|
| Key | số nguyên `[0]`, `[1]`, ... | string ổn định `["alpha"]`, `["bravo"]`, ... |
| Thêm 1 phần tử vào giữa | **mọi phần tử sau dịch index** → recreate cascade | chỉ instance mới được tạo |
| Address ổn định | KHÔNG (theo thứ tự) | CÓ (theo key) |
| Truyền dữ liệu khác nhau cho mỗi instance | khó (qua `count.index` lookup) | dễ (qua `each.value`) |
| Cú pháp ngắn | đôi khi (boolean toggle: `count = enabled ? 1 : 0`) | luôn rõ ràng |

**Quy tắc:** mặc định dùng `for_each` với key có ý nghĩa. Chỉ dùng `count` cho:
- Toggle bật/tắt resource (`count = enabled ? 1 : 0`).
- Số lượng N đồng nhất, **không quan tâm thứ tự** (hiếm khi đúng).

Khi đã apply rồi muốn refactor `count → for_each`, dùng `moved {}` block để tránh
destroy/recreate (lab 09).

### `dynamic` block — sức mạnh và cạm bẫy

`dynamic` cho phép sinh nested block từ collection:

```hcl
dynamic "labels" {
  for_each = local.merged_labels   # map hoặc list
  content {
    label = labels.key            # iterator name = block name
    value = labels.value
  }
}
```

**Anti-pattern:** lạm dụng `dynamic` cho block luôn có **đúng 1** entry — code khó đọc hơn,
mà cũng không tận dụng được sức mạnh động. Chỉ dùng `dynamic` khi:
- Số block thay đổi theo input (`enable_x ? 1 : 0`).
- Lặp qua collection (label, ingress rule, ...).

### `templatefile()` vs `file()` + `format()`

| Cách | Khi nào dùng |
|------|--------------|
| `file("path")` | Đọc nguyên file, không thay biến |
| `templatefile("path", { var = ... })` | Có chỗ chèn biến, vòng lặp `%{ for }`, điều kiện `%{ if }` |
| `format(...)` + biểu thức | Chuỗi ngắn (1–3 dòng) |

Cú pháp template syntax: `${expr}` interpolate, `%{ if cond }...%{ endif }`,
`%{ for x in list }...%{ endfor }`. **Lưu ý:** dùng `~` để strip whitespace:
`%{~ for x ~}` — quan trọng khi render YAML/JSON sensitive với indentation.

### `splat` vs `for` expression

```hcl
# Splat — chỉ lấy 1 attribute, ngắn gọn:
[for c in docker_container.app : c.name]   # ≡
docker_container.app[*].name               # (cho count)
values(docker_container.app)[*].name       # (cho for_each, hơi dài)

# for expression — flexible, có filter, có thể tạo map:
{ for k, v in var.services : k => "http://localhost:${v.external_port}" }
[for s in var.services : s.image if s.enable_healthcheck]
```

### Cạm bẫy thường gặp

1. **`for_each` trên unknown-at-plan-time:** `for_each = { for k, v in resource.x : k => v }`
   → nếu `resource.x` chưa apply, key chưa biết → Terraform báo lỗi
   "The 'for_each' map includes keys derived from resource attributes that cannot be
   determined until apply". Giải: dùng key tĩnh, hoặc tách thành 2 stage.
2. **Đổi `count` thành `for_each` mà không dùng `moved`:** Terraform thấy resource cũ
   (`.x[0]`) "biến mất", resource mới (`.x["foo"]`) "xuất hiện" → destroy + create.
3. **`plantimestamp()` trong attribute không có `ignore_changes`:** mỗi plan đều có giá trị
   mới → constant drift. Hoặc chấp nhận (chỉ dùng làm output), hoặc dùng `lifecycle {
   ignore_changes = [attribute] }`. Lab này chỉ output, không gắn vào resource attribute.
4. **`templatefile` không tìm thấy file:** path tương đối tính từ `path.module`, không phải
   working dir. Dùng `"${path.module}/templates/x.tftpl"`.
5. **`env` của `docker_container` là `set(string)`, không phải block.** Cần truyền list
   `["KEY=VAL", ...]`, không phải `block { name=..., value=... }`. Đó là lý do dùng
   `for expression` trong lab này.

### Docs tham khảo

- Functions: <https://developer.hashicorp.com/terraform/language/functions>
- `for_each` vs `count`: <https://developer.hashicorp.com/terraform/language/meta-arguments/for_each>
- `dynamic` blocks: <https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks>
- `templatefile`: <https://developer.hashicorp.com/terraform/language/functions/templatefile>
- `splat` vs `for`: <https://developer.hashicorp.com/terraform/language/expressions/for>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
