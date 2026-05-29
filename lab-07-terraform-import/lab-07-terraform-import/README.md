# Lab 07 — Terraform Import (classic)

> **Cấp độ:** Nâng cao
> **Thời lượng dự kiến:** ~60 phút
> **Yêu cầu trước:** Lab 00–06.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Hiểu vì sao** có resource "ngoài Terraform" (legacy, click-ops, sự cố
   incident response, đội khác tạo bằng tay) và tại sao "destroy + recreate
   để cho gọn" là **sai** trong production.
2. **Thực hiện** vòng đời `terraform import` cổ điển: viết resource block →
   `terraform import <addr> <id>` → `terraform plan` (DỰ KIẾN có diff) →
   tinh chỉnh block → đạt **0 changes** → apply (no-op refresh).
3. **Hiểu rõ**: `terraform import` chỉ đẩy resource vào **state**, KHÔNG
   sinh ra config. Bạn phải tự viết resource block khớp với thực tế.
4. **Đọc state** sau import: `terraform state list`, `terraform state show <addr>`
   — dùng output để copy attribute thực tế về `main.tf`.
5. **Phân biệt** rõ: `import` (đưa vào state) ≠ `apply` (đẩy ra hạ tầng).
   Nếu config sai khớp, lần `apply` tiếp theo có thể MODIFY hoặc DESTROY
   resource bạn vừa import.
6. **Tránh anti-pattern**: sửa file `terraform.tfstate` bằng tay; dùng `destroy`
   để "khởi động lại sạch".

## 🌐 Bối cảnh

Phòng vận hành 3 tháng trước có 1 incident lúc nửa đêm. On-call SRE đã tạo
1 container nginx (`tflab-07-legacy-app`, port 8110) và 1 volume
(`tflab-07-legacy-data`) bằng `docker run` — chữa cháy nhanh, không kịp viết
Terraform. Container đó hiện đang serve traffic.

Sếp giao bạn nhiệm vụ: **"đưa nó vào Terraform mà KHÔNG được downtime"**.
Bạn không được `docker rm` rồi `terraform apply` để "cho sạch" — container
đang chạy có volume gắn liền, recreate đồng nghĩa mất `/var/data`. Đây là
kịch bản kinh điển cho **classic `terraform import`**.

## 📋 Yêu cầu cụ thể

### Bước chuẩn bị (chạy 1 lần)

- [ ] `bash setup.sh` — tạo container `tflab-07-legacy-app` + volume
      `tflab-07-legacy-data` bằng `docker run` (mô phỏng "legacy stack").

### File `starter/main.tf`

- [ ] `resource "docker_image" "nginx"` — `name = "nginx:1.27-alpine"`,
      `keep_locally = true`. Image **không** import; chỉ declare bình thường
      (Docker pull idempotent, image hash sẽ stable).
- [ ] `resource "docker_volume" "legacy_data"` — `name = "tflab-07-legacy-data"`.
- [ ] `resource "docker_container" "legacy_app"`:
  - `name  = "tflab-07-legacy-app"`
  - `image = docker_image.nginx.image_id`
  - 1 block `ports { internal = 80; external = 8110 }`
  - 1 block `volumes { volume_name = docker_volume.legacy_data.name; container_path = "/var/data" }`
  - `restart = "unless-stopped"`, `must_run = true`, `network_mode = "bridge"`,
    `log_driver = "json-file"` (xem README "Đào sâu" cho biết các attribute
    này đến từ đâu).

### File `starter/outputs.tf`

- [ ] `container_id` — `docker_container.legacy_app.id`
- [ ] `volume_name` — `docker_volume.legacy_data.name`
- [ ] `url`         — `"http://localhost:8110"` (lấy từ block `ports`)

### Trạng thái cuối

- [ ] `terraform state list` chứa: `docker_image.nginx`, `docker_volume.legacy_data`,
      `docker_container.legacy_app`.
- [ ] `terraform plan -detailed-exitcode` exit 0 (0 changes).
- [ ] Container `tflab-07-legacy-app` **vẫn đang chạy** (không bị recreate).
- [ ] Volume `tflab-07-legacy-data` **vẫn tồn tại** (cùng tên).

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Kiểm tra cụ thể:

- `terraform fmt -check -recursive` (starter) sạch.
- `terraform validate` (starter) pass.
- State có đủ 3 resource (image, volume, container).
- ID container trong state KHỚP `docker inspect tflab-07-legacy-app`.
- `terraform plan -detailed-exitcode` → exit 0 (idempotent ngay sau import).
- Plan **với `-refresh=false`** cũng → 0 changes (config thực sự khớp state,
  không phải refresh "che" diff).
- Container & volume legacy vẫn còn nguyên (NOT destroyed).

## 🧭 Hướng dẫn làm

```bash
# 1) Tạo "legacy stack" ngoài Terraform.
bash setup.sh

# 2) Vào starter, init Terraform.
cd starter
terraform init

# 3) Viết 3 resource block ESTIMATE vào main.tf (xem TODO C1..C3).
#    Đừng cố hoàn hảo — bạn sẽ tinh chỉnh sau khi import.
$EDITOR main.tf

# 4) Import volume (volume identify bằng NAME):
terraform import docker_volume.legacy_data tflab-07-legacy-data

# 5) Import container (container identify bằng full container ID — không phải tên):
CID=$(docker inspect --format '{{.Id}}' tflab-07-legacy-app)
terraform import docker_container.legacy_app "${CID}"

# 6) Inspect state sau import — đây là LIVE TRUTH, copy về main.tf:
terraform state list
terraform state show docker_container.legacy_app

# 7) Plan để thấy diff. Lần đầu BÌNH THƯỜNG có diff
#    (provider defaults khác giá trị thật).
terraform plan

# 8) Tinh chỉnh main.tf để đóng từng diff:
#    - thêm restart = "unless-stopped"
#    - thêm network_mode = "bridge"
#    - thêm log_driver = "json-file"
#    - v.v.
#    Mục tiêu: `terraform plan` báo "No changes".

# 9) Khi plan = 0 changes, apply (chỉ refresh):
terraform apply

# 10) Hoàn thiện outputs.tf, rồi:
cd ..
bash verify.sh

# Dọn dẹp khi xong:
cd starter && terraform destroy
cd .. && bash teardown.sh
```

## 🧠 Đào sâu (expert)

### Vì sao `terraform plan` ngay sau import luôn có diff?

Khi bạn `terraform import`, Terraform đọc TOÀN BỘ attribute của resource thật
từ provider rồi đẩy vào state. Resource block của bạn (chỉ ghi vài attribute
"đẹp") **không đủ** — provider sẽ điền các attribute còn lại bằng **default
schema value** khi plan, và default thường khác với giá trị thật.

Ví dụ rất thực tế từ `kreuzwerker/docker_container`:

| Attribute | Default trong schema | Giá trị thực sau `docker run` |
|---|---|---|
| `restart` | `"no"` | `"unless-stopped"` (vì `--restart unless-stopped`) |
| `network_mode` | `""` | `"bridge"` (Docker assign mặc định) |
| `log_driver` | `""` | `"json-file"` (Docker default trên host này) |
| `must_run` | `true` | `true` — match, không diff |

Mỗi mismatch là 1 dòng diff. Cách đúng: **đọc `terraform state show <addr>`**,
copy giá trị thật về block của bạn, lặp lại đến khi plan sạch.

### `terraform import` KHÔNG đụng đến hạ tầng (an toàn)

Lệnh `import` chỉ đọc + ghi state. Không gọi API mutate. Nếu sai sót, bạn
có thể `terraform state rm <addr>` để rút khỏi state mà resource thật **vẫn
nguyên vẹn**. (Đây là sự khác biệt cốt lõi với `apply`.)

**Nhưng cẩn thận lần `apply` đầu tiên sau import:** nếu config block sai khớp
nặng, `apply` có thể MODIFY hoặc thậm chí FORCE NEW (destroy + create) resource
bạn vừa import. Ví dụ kinh điển: bạn quên `network_mode = "bridge"` → provider
muốn "fix" sang `""` → một số change attribute đó **bắt buộc replace** → ✘ mất
container.

**Quy tắc vàng:** TUYỆT ĐỐI không `terraform apply` cho đến khi `plan` = 0 changes.

### Khi nào dùng `lifecycle { ignore_changes = [...] }`?

Đây là **band-aid cuối cùng** — chỉ dùng khi attribute thật sự không thể
control: ID auto-generated bởi cloud, timestamp `created_at`, tag tự inject
bởi management agent, v.v.

```hcl
resource "docker_container" "legacy_app" {
  # ...
  lifecycle {
    ignore_changes = [
      # AWS-style: managed_by_someone_else_dont_touch
      labels,
    ]
  }
}
```

**Anti-use:** dùng `ignore_changes` để giấu diff vì lười tinh chỉnh config.
Mục tiêu là config trở thành **single source of truth**. Mỗi lần bạn
`ignore_changes`, bạn đánh đổi truth lấy convenience — nợ kỹ thuật.

### Đọc state sau import (workflow chuyên gia)

```bash
# Xem địa chỉ state đầy đủ:
terraform state list

# Xem mọi attribute của 1 resource:
terraform state show docker_container.legacy_app

# So sánh state với live (rare — provider tự refresh trong plan):
terraform plan -refresh-only
```

`state show` xuất ra HCL-like format. Bạn có thể **copy-paste trực tiếp** vào
`main.tf` rồi xoá những attribute computed (`id`, `bridge`, `gateway`, …)
hoặc attribute trùng default. Đây là cách nhanh nhất để đạt 0-diff.

### Anti-pattern: edit `terraform.tfstate` bằng tay

State file là JSON. Nó **trông** sửa được. **ĐỪNG.** Lý do:

1. State có checksum & versioning. Edit tay → format hỏng → `terraform plan`
   crash hoặc tệ hơn — diff sai lệch khó debug.
2. Nhiều resource có inter-reference (resource A reference B qua ID). Sửa 1
   trường có thể vô hiệu cả đồ thị dependency.
3. Mất history. State file là single source — sửa tay = mất audit trail.

Mọi sửa state PHẢI qua CLI: `terraform import`, `terraform state mv`,
`terraform state rm`, `terraform state replace-provider` (lab 09).

### Backup state TRƯỚC khi surgery

```bash
cp terraform.tfstate "terraform.tfstate.backup-$(date +%s)"
```

Terraform có tự backup vào `.tfstate.backup` sau mỗi `apply`, nhưng chỉ giữ
1 bản. Trước thao tác nguy hiểm (import bulk, state rm, state mv), tự copy
ra tên có timestamp để có nhiều generation rollback.

### Classic CLI import vs `import {}` block (lab 08)

| Tiêu chí | Classic CLI (lab này) | `import {}` block (lab 08) |
|---|---|---|
| Khai báo | 1 lệnh CLI per resource | Khai báo trong code |
| Plannable | KHÔNG (mutate state ngay) | CÓ (xem được trước apply) |
| Reviewable trong PR | KHÔNG | CÓ |
| Bulk | Phải gõ N lần | 1 plan + apply duy nhất |
| Codegen | Phải tự viết resource block | `-generate-config-out` sinh khung |
| Khi nào dùng | 1-2 resource ad-hoc, fix nóng | Bulk import, audit-able |

Học classic trước vì nó dạy bạn **cách Terraform import thực sự nghĩ**.
Block form đẹp hơn nhưng giấu đi cơ chế — biết cả 2 mới đúng.

### Cạm bẫy thường gặp

1. **Quên `terraform init` trước import.** Lỗi: "Initialization required."
2. **Import bằng container NAME thay vì ID.** Lỗi: "Unable to find container".
   Docker provider yêu cầu full container ID (`docker inspect --format '{{.Id}}'`).
   Volume thì ngược lại — identify bằng name.
3. **Apply ngay sau import khi plan còn diff.** Container của bạn vừa import
   xong có thể bị recreate. Luôn đợi plan = 0 changes.
4. **Comment `# imported manually 2024-01-15` rồi quên.** Sau 6 tháng người
   khác đọc không hiểu sao block này "thiếu" attribute. Comment phải nói
   **vì sao**, không phải "khi nào".
5. **Reimport sau khi xoá khỏi state.** `terraform state rm` rồi `terraform
   import` lại OK, nhưng trong khoảng đó nếu ai đó `terraform apply` thì
   Terraform sẽ thấy "config có, state không" → CREATE → trùng resource thật.
   Luôn `state rm` + `import` cùng PR/session.

### Docs tham khảo

- `terraform import` CLI: <https://developer.hashicorp.com/terraform/cli/import>
- Import usage: <https://developer.hashicorp.com/terraform/cli/import/usage>
- Docker provider `docker_container` import: <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container#import>
- Docker provider `docker_volume` import: <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/volume#import>
- State management: <https://developer.hashicorp.com/terraform/cli/state>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
