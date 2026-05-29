# Lab 00 — Setup & Foundations

> **Cấp độ:** Cơ bản
> **Thời lượng dự kiến:** ~30 phút
> **Yêu cầu trước:** Đã chạy `bash scripts/check-env.sh` thành công (Terraform >= 1.9, Docker đang chạy).

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Hiểu** vòng đời Terraform `init → plan → apply → destroy` và biết khi nào dùng từng lệnh.
2. **Khai báo** đúng cú pháp khối `terraform { required_version, required_providers }`.
3. **Tạo** resource đầu tiên: 1 `docker_image` + 1 `docker_container` chạy nginx.
4. **Đọc state** bằng `terraform state list` và `terraform state show`.
5. **Phân biệt** ba khái niệm: file config (`.tf`) vs. file state (`terraform.tfstate`) vs. lock file (`.terraform.lock.hcl`).

## 🌐 Bối cảnh

Bạn vừa gia nhập đội platform. Lead giao bài tập "Hello, Terraform" để xác nhận bạn cài máy
đúng: dựng **1 container nginx** trên cổng **8080** bằng Terraform — không click chuột Docker
Desktop, không gõ `docker run`. Mọi thay đổi phải đi qua `terraform apply`.

## 📋 Yêu cầu cụ thể

- [ ] File `versions.tf` khai báo `required_version >= 1.9.0` và `required_providers` chỉ cho
      provider `kreuzwerker/docker ~> 3.0` (không thừa provider nào khác).
- [ ] Resource `docker_image.nginx` kéo image **`nginx:1.27-alpine`** (pin version, không dùng
      tag `latest`).
- [ ] Resource `docker_container.hello`:
  - `name = "tflab-00-hello"`
  - tham chiếu image qua `docker_image.nginx.image_id` (KHÔNG hardcode chuỗi image)
  - map cổng **`8080:80`** (external:internal)
  - `restart = "unless-stopped"`
- [ ] Hai output:
  - `container_id` — ID đầy đủ của container
  - `url` — chuỗi `"http://localhost:8080"`
- [ ] `terraform fmt -check -recursive` trong `starter/` không sửa file nào.
- [ ] `terraform validate` exit code 0.
- [ ] Sau `terraform apply`, truy cập `http://localhost:8080` thấy trang nginx mặc định.

## ✅ Tiêu chí pass

- `terraform fmt -check -recursive` không sửa file.
- `terraform validate` exit 0.
- `bash verify.sh` in `PASS` và exit 0.
- `terraform output url` trả về chuỗi chứa `http://localhost:8080`.
- Container `tflab-00-hello` xuất hiện trong `docker ps`.

## 🧭 Hướng dẫn làm

```bash
# 1. Vào starter
cd starter

# 2. Mở main.tf và outputs.tf, đọc các comment "TODO" và điền giá trị đúng
#    (đừng nhìn ../solution/ vội).

# 3. Khởi tạo Terraform (tải provider docker, tạo lock file)
terraform init

# 4. Xem dry-run: Terraform sẽ làm gì?
terraform plan

# 5. Apply thực sự — đọc kỹ "Plan: 2 to add" trước khi gõ "yes"
terraform apply

# 6. Mở browser http://localhost:8080 — phải thấy "Welcome to nginx!"
#    hoặc: curl -s http://localhost:8080 | head -1

# 7. Xem state
terraform state list
terraform state show docker_container.hello

# 8. Đọc output
terraform output

# 9. Chạy verify.sh từ thư mục lab
cd ..
bash verify.sh

# 10. Khi pass — dọn dẹp
cd starter
terraform destroy
```

## 🧠 Đào sâu (expert)

### Vì sao tách `docker_image` thành resource riêng?

Khi viết `docker run nginx`, Docker sẽ pull image nếu chưa có rồi tạo container — gộp 2 bước.
Trong Terraform, tách image ra resource riêng (`docker_image`) đem lại **lifecycle separation**:

- State track **image ID** (sha256) chứ không chỉ tag → bạn biết chính xác bản nào đang chạy.
- Khi bạn bump `nginx:1.27-alpine` lên `1.28-alpine`, `terraform plan` thấy `docker_image.nginx`
  cần replace, kéo theo `docker_container.hello` được recreate (vì phụ thuộc qua `image_id`).
  Nếu chỉ viết `image = "nginx:1.27-alpine"` thẳng trong container, Docker chỉ pull mới khi
  image chưa có — drift tiềm ẩn.
- Lúc `destroy`, container biến mất; image vẫn nằm local (do `keep_locally = true`) → các lab
  sau init nhanh hơn vì không phải pull lại.

### `.tf` vs `terraform.tfstate` vs `.terraform.lock.hcl`

| File | Mục đích | Có commit vào git? |
|------|----------|--------------------|
| `*.tf` | Định nghĩa **mong muốn** (desired state) | **Có** |
| `terraform.tfstate` | Snapshot **thực tế** Terraform đã tạo (chứa ID, attribute) | **Không** (sensitive; lab sau sẽ học remote backend) |
| `.terraform.lock.hcl` | Pin provider hash để team build reproducible | **Có** |
| `.terraform/` | Cache provider binary của lần `init` cục bộ | **Không** |

Edit tay `.tfstate` là **anti-pattern nghiêm trọng** — lab 09 sẽ dạy cách dùng `terraform state` CLI
và `moved {}` block để refactor an toàn.

### Vòng đời lệnh

```
   ┌────────┐   ┌────────┐   ┌────────┐   ┌──────────┐
   │  init  │ → │  plan  │ → │ apply  │ → │ destroy  │
   └────────┘   └────────┘   └────────┘   └──────────┘
   tải plugin   so sánh      thực hiện     tear-down
   tạo lock     desired      thay đổi
                vs state
```

`plan` **không** thay đổi gì ngoài đời thật. `apply` đọc state, gọi provider API (ở đây là Docker
socket), rồi ghi state mới.

### Cạm bẫy thường gặp

1. **Port 8080 đã bị chiếm.** `docker ps`/`lsof -i :8080` để check; đổi `external` nếu cần.
2. **Docker socket cần quyền.** Trên Linux, user phải thuộc group `docker` hoặc dùng rootless.
3. **`image = "nginx:1.27-alpine"` thay vì `image = docker_image.nginx.image_id`.** Vẫn chạy,
   nhưng phá lifecycle separation ở trên — Terraform sẽ không track image_id trong state.
4. **Commit `terraform.tfstate` vào git.** Đã có trong `.gitignore` của repo này; nếu lỡ commit
   thì `git rm --cached`.

### Docs tham khảo

- Terraform Language overview: <https://developer.hashicorp.com/terraform/language>
- `docker_image` resource: <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/image>
- `docker_container` resource: <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container>
- Provider requirements: <https://developer.hashicorp.com/terraform/language/providers/requirements>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3, đừng nhảy thẳng xuống bậc 3).
