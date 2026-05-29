# Lab 08 — Import Blocks + Codegen

> **Cấp độ:** Nâng cao
> **Thời lượng dự kiến:** ~75 phút
> **Yêu cầu trước:** Lab 00–07 (đặc biệt Lab 07: classic `terraform import`).

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Khai báo** `import {}` block trong code — declarative, plannable,
   reviewable thông qua PR. Hiểu nó **thay thế** classic `terraform import`
   CLI cho hầu hết use case.
2. **Sinh khung config** bằng `terraform plan -generate-config-out=generated.tf`
   — Terraform tự đọc live attribute và viết resource block "draft".
3. **Bulk import**: import N resource cùng lúc bằng `for_each` trên
   import block (TF 1.7+) — 1 plan, 1 apply.
4. **Cleanup `generated.tf`**: refactor file "thô" thành idiomatic style
   (locals, for_each, naming, DRY). Hiểu vì sao codegen là điểm BẮT ĐẦU,
   không phải đáp án cuối.
5. **So sánh** classic `terraform import` (lab 07) vs import block (lab này)
   và biết khi nào dùng cái nào.
6. **Hiểu giới hạn** của codegen: không sinh cho child module resource;
   không tự áp dụng `for_each`; không gộp duplicate.

## 🌐 Bối cảnh

Tiếp nối lab 07: phòng vận hành đã quyết "from now on, all infra is in
Terraform". Hôm nay họ đưa cho bạn cả 1 "legacy stack" được tạo bằng tay
ngoài Terraform suốt 3 tháng qua:

- 1 user-defined bridge network: `tflab-08-net`
- 2 named volume: `tflab-08-data1`, `tflab-08-data2`
- 3 container nginx: `tflab-08-app1` (port 8111, mount data1),
  `tflab-08-app2` (port 8112, mount data2), `tflab-08-app3` (port 8113,
  không volume)

Yêu cầu: đưa cả stack vào Terraform, **plannable, audit-able, không gõ
6 lệnh `terraform import`**. Đây là use case kinh điển của `import {}`
block + `-generate-config-out`.

## 📋 Yêu cầu cụ thể

### Bước chuẩn bị

- [ ] `bash setup.sh` — tạo legacy stack (1 net + 2 vol + 3 ctnr).

### File `starter/imports.tf`

- [ ] `data "external" "container_ids"` — emit JSON
      `{app1, app2, app3}` từ `docker inspect --format '{{.Id}}'`.
- [ ] 1 `import {}` block cho network: `to = docker_network.main`,
      `id = "tflab-08-net"`.
- [ ] 1 `import {}` block với `for_each = local.volumes` cho 2 volume,
      `to = docker_volume.this[each.key]`, `id = "tflab-08-${each.key}"`.
- [ ] 1 `import {}` block với `for_each = local.apps` cho 3 container,
      `to = docker_container.app[each.key]`,
      `id = data.external.container_ids.result[each.key]`.

### File `starter/main.tf` (sau refactor)

- [ ] `locals.apps`    = map có 3 entry `{ port, volume }`.
- [ ] `locals.volumes` = `toset(["data1", "data2"])`.
- [ ] `docker_image.nginx` (declared bình thường, KHÔNG import).
- [ ] `docker_network.main` — name = `tflab-08-net`, driver `bridge`.
- [ ] `docker_volume.this` với `for_each = local.volumes`.
- [ ] `docker_container.app` với `for_each = local.apps`:
  - `networks_advanced { name = docker_network.main.name }`
  - `ports { internal = 80, external = each.value.port }`
  - `dynamic "volumes"` chỉ render khi `each.value.volume != null`
  - các attribute zero-diff: `restart = "unless-stopped"`, `must_run`,
    `network_mode = "default"`, `log_driver = "json-file"`.

### File `starter/outputs.tf`

- [ ] `urls`       — map `{ app_key => "http://localhost:<port>" }`.
- [ ] `network_id` — `docker_network.main.id`.
- [ ] `volumes`    — list (sorted) các volume name.

### Trạng thái cuối

- [ ] `terraform state list` chứa: `docker_image.nginx`,
      `docker_network.main`, `docker_volume.this["data1"]`,
      `docker_volume.this["data2"]`, `docker_container.app["app1"]`,
      `docker_container.app["app2"]`, `docker_container.app["app3"]`,
      và `data.external.container_ids`.
- [ ] Cả 6 resource Docker pre-existing **vẫn còn nguyên** (NOT destroyed).
- [ ] `terraform plan -detailed-exitcode` exit 0.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể:

- `terraform fmt -check -recursive` (starter) sạch.
- `terraform validate` (starter) pass.
- 7 resource expected có trong state.
- 6 resource Docker pre-existing vẫn tồn tại (live).
- `terraform plan -detailed-exitcode` → exit 0 (idempotent).
- `terraform plan -refresh=false -detailed-exitcode` → exit 0 (config thực
  sự khớp state).
- Output `urls`, `network_id`, `volumes` đúng giá trị mong đợi.

## 🧭 Hướng dẫn làm

```bash
# 1) Tạo legacy stack ngoài Terraform.
bash setup.sh

# 2) Init.
cd starter
terraform init

# 3) Viết imports.tf — 1 data "external" + 3 import blocks (1 + 2 + 3
#    objects qua for_each).
$EDITOR imports.tf

# 4) CODEGEN — chỉ trỏ vào imports.tf, Terraform tự sinh resource block
#    "draft" vào generated.tf. KHÔNG mutate state ở bước này.
terraform plan -generate-config-out=generated.tf

# 5) Mở generated.tf — sẽ thấy 6 resource block "rất thô":
#    - tách rời (không for_each)
#    - mọi attribute kể cả default
#    - đặt tên theo địa chỉ ban đầu (vd: docker_container.tflab-08-app1)
#
#    KHÔNG dùng nó như đáp án cuối. Đây là nguyên liệu.

# 6) Refactor: gộp 3 container → 1 resource for_each map (xem main.tf
#    skeleton trong HINTS bậc 2). Tương tự cho 2 volume → for_each set.
#    Tách image ra 1 resource shared.
#    Sửa `to = ...` trong imports.tf cho khớp address mới.
$EDITOR main.tf imports.tf outputs.tf

# 7) Khi address ổn định, kiểm tra plan vẫn báo "to import":
terraform plan
# Đầu ra mong đợi:
#   Plan: 6 to import, 0 to add, 0 to change, 0 to destroy.

# 8) Apply — 6 resource vào state. Hạ tầng Docker không thay đổi.
terraform apply

# 9) Idempotency:
terraform plan       # phải báo "No changes"

# 10) Xoá generated.tf (chỉ là draft).
rm generated.tf

# 11) Tuỳ chọn: xoá imports.tf — state đã giữ resource, import block
#     "đã làm xong việc". Hoặc giữ làm audit trail (đọc "Đào sâu").
# rm imports.tf

cd ..
bash verify.sh

# Dọn dẹp khi xong (DESTROY sẽ xoá hết — kể cả 6 resource imported):
cd starter && terraform destroy
cd .. && bash teardown.sh   # idempotent, không lỗi nếu đã destroy
```

## 🧠 Đào sâu (expert)

### Import block syntax & semantics

```hcl
import {
  to = docker_container.app["app1"]
  id = "9a550c0f0163..."   # full container ID
}
```

- `to` — Terraform address (có thể là `for_each` instance: `[each.key]`).
- `id` — expression known-at-plan-time. Có thể là literal, variable,
  data source attribute, hay `each.value` trong `for_each`.
- `for_each` (TF ≥ 1.7) — chạy import N lần, một per element.
- Khối này **declarative** — chỉ mô tả ý định. Mutate state chỉ xảy ra
  khi `apply`.

### `-generate-config-out` — nó làm gì và **không** làm gì

```bash
terraform plan -generate-config-out=generated.tf
```

**Làm:**
- Đọc live attribute của mỗi resource trong import block.
- Sinh resource block với MỌI attribute (kể cả default).
- Đặt tên theo địa chỉ trong `to = ...`.

**Không làm:**
- Không gộp duplicate (3 nginx container thành 1 for_each).
- Không suy luận `locals`/`variables`.
- Không hỗ trợ child module resource (chỉ root module).
- Không skip attribute computed/sensitive — có thể leak secret vào file.
- Không format đẹp — bạn `terraform fmt` lại.

→ Codegen là **scaffolding**. Luôn refactor trước commit.

### Vì sao import block > classic CLI?

| Tiêu chí | Classic `terraform import` | `import {}` block |
|---|---|---|
| Sống ở đâu | Lệnh shell (history, manual) | Trong code, version-controlled |
| Plannable | KHÔNG (mutate ngay) | CÓ |
| Reviewable | KHÔNG (PR không thấy) | CÓ |
| Bulk | Gõ N lần | for_each |
| Codegen | Không | `-generate-config-out` |
| Rollback | `state rm` sau khi đã mutate | Sửa block + plan lại |
| Khi nào dùng | Fix nóng ad-hoc 1 resource | Default cho mọi import "có chuẩn bị" |

Trong production team: dùng import block. Classic CLI để khi không tiện
mở editor (vd: incident response giữa đêm).

### Giới hạn (TF 1.14)

1. **Không hỗ trợ child module resource trong codegen.** `to = module.x.r["k"]`
   sẽ chạy được import, nhưng `-generate-config-out` báo lỗi. Workaround:
   import block ở root, refactor sang module ở bước riêng.
2. **`provider` override per-import chưa có.** Mọi import dùng provider mặc
   định của address. Nếu cần alias, đặt `provider = docker.east` trong
   resource block (như lab 06), không phải trong import block.
3. **`for_each` trên import block** yêu cầu collection biết được lúc plan.
   Dùng `local.apps` (cố định) — KHÔNG dùng `data` từ remote API mà
   collection có thể thay đổi giữa plan và apply.

### Cleanup strategy: xoá imports.tf hay giữ?

Cả 2 hợp lệ. Bảng quyết định:

| Tình huống | Khuyến nghị |
|---|---|
| Team nhỏ, repo bình thường | Xoá sau apply thành công |
| Repo có audit policy (SOX, ISO) | Giữ + comment "imported on YYYY-MM-DD by `<ticket>`" |
| Sắp import thêm resource cùng loại | Giữ — chỉ thêm `for_each` element |
| File quá dài / nhiều generation import | Tách thư mục `imports/2024-Q4.tf` rồi xoá theo quarter |

Nếu giữ, **chú ý**: chạy `terraform plan` ở lần sau sẽ in dòng "Resource is
already imported" nhưng vẫn no-op — vô hại nhưng noise. Một số team chấp nhận.

### Bulk import patterns ở quy mô

Khi cần import 100+ resource (vd: cả AWS account vào Terraform):

```hcl
locals {
  legacy_buckets = jsondecode(file("${path.module}/inventory/buckets.json"))
}

import {
  for_each = local.legacy_buckets
  to       = aws_s3_bucket.legacy[each.key]
  id       = each.value.name
}
```

→ Inventory list là input. Generate code, refactor, apply 1 lần. Repeat
cho từng "domain" (S3, EC2, IAM, …).

### Anti-pattern: relying on generated.tf as-is

Commit `generated.tf` thẳng → 6 tháng sau:
- Đọc khó (mỗi resource lặp 30 dòng default).
- Sửa khó (đổi 1 port phải sửa 3 resource).
- DRY vi phạm trắng trợn.

Codegen là **draft** giống `git commit --amend` — luôn refactor trước
review.

### Cạm bẫy thường gặp

1. **Quên `terraform plan -generate-config-out` cần `imports.tf` đã viết.**
   Nếu chưa có import block, codegen không có gì để sinh.
2. **`id` của container hardcode theo container hiện tại.** Sang môi
   trường khác (staging, prod) ID khác → import fail. Luôn dùng
   `data "external"` hoặc input variable.
3. **`for_each` trên import + key dynamic.** Key phải biết được ở plan
   time. Đừng dùng `for_each = data.X.result.list` nếu list có thể đổi.
4. **Sửa `to = ...` trong imports.tf SAU apply.** Lúc đó resource đã ở
   state với address cũ — đổi `to` chỉ tạo import mới, KHÔNG move resource
   hiện có. Để move dùng `moved {}` (lab 09).
5. **Import resource vào address có instance đã tồn tại.** Lỗi:
   "Resource is already imported / already in state". `terraform state rm`
   trước khi reimport.
6. **`-generate-config-out` ghi đè file nếu tồn tại.** Backup hoặc dùng
   tên khác (`generated-$(date +%s).tf`).

### Docs tham khảo

- `import {}` block: <https://developer.hashicorp.com/terraform/language/import>
- Generating configuration: <https://developer.hashicorp.com/terraform/language/import/generating-configuration>
- Import for_each (1.7+ release notes): <https://github.com/hashicorp/terraform/releases/tag/v1.7.0>
- `external` data source: <https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external>
- Docker container import: <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container#import>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
