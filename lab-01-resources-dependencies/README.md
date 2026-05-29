# Lab 01 — Resources & Dependencies

> **Cấp độ:** Cơ bản
> **Thời lượng dự kiến:** ~45 phút
> **Yêu cầu trước:** Đã hoàn thành Lab 00.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Tạo** nhiều resource có dependency lẫn nhau (network + 2 container).
2. **Phân biệt** *implicit* dependency (qua attribute reference) vs. *explicit* `depends_on`.
3. **Vẽ** dependency graph bằng `terraform graph` và đọc được nó (tuỳ chọn).
4. **Đọc state** chi tiết hơn: `terraform state list`, `state show`, `state pull` (read-only).
5. **Hiểu** khi nào `terraform plan` báo *update-in-place* và khi nào *replace* (recreate).
6. **Chứng minh** tính idempotent: sau khi apply, `terraform plan` lần 2 phải báo `0 changes`.

## 🌐 Bối cảnh

Đội của bạn muốn dựng mini-stack "web + database" cho môi trường dev local. Yêu cầu:

- 1 **Docker network** riêng (`tflab-01-net`) để cô lập khỏi network mặc định.
- 1 container **db** (chạy redis làm DB đơn giản, không cần persistence).
- 1 container **web** (nginx) **phải khởi động sau db** — vì web kết nối db lúc start (giả lập
  thôi, không kết nối thật).
- web phải public ra cổng **8081** trên host.

Mọi container chạy cùng network để có thể ping nhau qua DNS Docker.

## 📋 Yêu cầu cụ thể

- [ ] `versions.tf` — chỉ provider `kreuzwerker/docker ~> 3.0`.
- [ ] `docker_network.app` — `name = "tflab-01-net"`.
- [ ] `docker_image.redis` — `redis:7-alpine`.
- [ ] `docker_image.nginx` — `nginx:1.27-alpine`.
- [ ] `docker_container.db`:
  - `name = "tflab-01-db"`
  - `image = docker_image.redis.image_id` (REFERENCE, không hardcode)
  - `networks_advanced { name = docker_network.app.name }`
- [ ] `docker_container.web`:
  - `name = "tflab-01-web"`
  - `image = docker_image.nginx.image_id`
  - `networks_advanced { name = docker_network.app.name }`
  - `ports { internal = 80, external = 8081 }`
  - **`depends_on = [docker_container.db]`** — explicit, để học khái niệm
- [ ] Outputs: `network_id`, `web_url`, `containers` (list 2 tên).
- [ ] `terraform fmt -check -recursive` sạch.
- [ ] `terraform validate` exit 0.
- [ ] Sau apply: `terraform plan` lần 2 báo `No changes`.

## ✅ Tiêu chí pass

- `bash verify.sh` in `PASS` và exit 0. Cụ thể `verify.sh` kiểm tra:
  - `terraform fmt` sạch, `terraform validate` exit 0.
  - State list chứa đủ 5 resource: network + 2 image + 2 container.
  - `docker inspect tflab-01-web` & `tflab-01-db` đều ở trạng thái `running`.
  - `docker network inspect tflab-01-net` chứa cả 2 container.
  - `terraform plan` lần 2 trả về exit code 0 với `0 changes`.

## 🧭 Hướng dẫn làm

```bash
cd starter
# Đọc các "TODO" trong main.tf và outputs.tf; điền giá trị/reference.

terraform init
terraform plan         # đọc kỹ phần "Plan: X to add"
terraform apply

# Xem dependency graph (tuỳ chọn — text nên rối, copy ra graphviz online để xem đẹp)
terraform graph | head -50

# Xem state
terraform state list
terraform state show docker_container.web
terraform output

# Idempotency check
terraform plan         # phải báo "No changes"

# Cross-check với Docker
docker network inspect tflab-01-net | jq '.[0].Containers'

# Verify
cd ..
bash verify.sh

# Dọn dẹp
cd starter
terraform destroy
```

## 🧠 Đào sâu (expert)

### Implicit vs. Explicit dependency

Terraform xây dependency graph **tự động** bằng cách quét reference giữa các resource:

```hcl
# IMPLICIT — Terraform thấy ".image_id" → biết container phụ thuộc image
resource "docker_container" "db" {
  image = docker_image.redis.image_id   # ← reference tạo edge graph
  networks_advanced {
    name = docker_network.app.name      # ← thêm edge tới network
  }
}
```

Khi nào cần **EXPLICIT** `depends_on`?

Khi **business logic** đòi ordering nhưng không có attribute reference nào để Terraform suy ra:

```hcl
# web KHÔNG đọc bất kỳ attribute nào của db,
# nhưng app code bên trong web mong db đã sẵn sàng khi nó khởi động.
resource "docker_container" "web" {
  # ... không có reference tới db ...
  depends_on = [docker_container.db]   # ← bắt buộc khai báo tay
}
```

**Quy tắc vàng:** ưu tiên *implicit* (refactor để có reference) — code dễ đọc hơn. Chỉ dùng
`depends_on` khi thực sự không cách nào khác (ví dụ phụ thuộc qua side-effect, IAM lan toả trong
cloud, vân vân). Lạm dụng `depends_on` làm graph cứng, plan chậm, dễ deadlock khi destroy.

### `terraform plan`: no-op / create / update-in-place / replace

Khi đọc plan, mỗi resource sẽ ở 1 trong các trạng thái:

| Ký hiệu | Ý nghĩa | Khi nào xảy ra |
|---------|---------|----------------|
| (no entry) | no-op — không thay đổi | desired = current |
| `+ create` | tạo mới | resource chưa có trong state |
| `~ update in-place` | sửa attribute không yêu cầu recreate | provider hỗ trợ patch |
| `-/+ replace` | xoá → tạo lại | đổi attribute mà schema đánh dấu `ForceNew` |
| `- destroy` | xoá | resource biến mất khỏi config |

Thử nghiệm: sau khi apply xong, đổi `external = 8081` → `8082` trong `ports {}` rồi `plan`. Bạn sẽ
thấy `-/+ destroy and then create replacement` — vì port mapping là ForceNew trong
schema `docker_container`. Đó là lý do tại sao đổi cổng → container bị recreate (mất uptime).

### `terraform graph` — đọc graph thật

```bash
terraform graph > graph.dot
# Mở https://dreampuf.github.io/GraphvizOnline/ và paste nội dung graph.dot
```

Bạn sẽ thấy edge từ `docker_container.web` → `docker_container.db` (nhờ `depends_on`) và edge
ngầm tới `docker_image.nginx` (nhờ reference `image_id`).

### Cảnh báo: ĐỪNG chỉnh tay `terraform.tfstate`

State là **source of truth của Terraform**. Edit tay → corrupt → next plan/apply behaviour không
xác định. Lab 09 sẽ dạy cách dùng `terraform state mv/rm/replace-provider` và `moved {}` /
`removed {}` block để refactor *an toàn*. Quy tắc bây giờ: **chỉ đọc** state (`state list`,
`state show`, `state pull > backup.tfstate`).

### Cạm bẫy thường gặp

1. **Vòng lặp `depends_on`.** Hai resource trỏ qua trỏ lại → Terraform báo cycle. Refactor để
   chỉ phụ thuộc 1 chiều.
2. **`depends_on` trong module.** Có thể nhưng phải đặt ở block `module {}` của caller — sẽ học
   ở Lab 05–06.
3. **`networks_advanced` vs. `network_mode`.** `networks_advanced` cho phép attach nhiều
   network và set IP cụ thể; `network_mode` chỉ cho 1 string đơn — lab này dùng cái đầu vì có
   network riêng.
4. **Pin tag image (`redis:7-alpine`) — không dùng `latest`.** Image `latest` sẽ làm
   `docker_image` thay đổi mỗi lần pull → drift không kiểm soát.

### Docs tham khảo

- Resource dependencies: <https://developer.hashicorp.com/terraform/language/resources/behavior#resource-dependencies>
- `depends_on` meta-argument: <https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on>
- `terraform graph`: <https://developer.hashicorp.com/terraform/cli/commands/graph>
- State CLI: <https://developer.hashicorp.com/terraform/cli/state>
- `docker_network`: <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/network>

## 🆘 Bí quá?

Xem `HINTS.md` (mở từng bậc).
