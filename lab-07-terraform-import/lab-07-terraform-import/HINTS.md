# Hints — Lab 07

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- Bạn không biết `terraform import` cần "địa chỉ" gì? Đó là Terraform address —
  giống output của `terraform state list`. Format: `<resource_type>.<name>`,
  ví dụ `docker_volume.legacy_data`.
- ID dùng cho import phụ thuộc resource type. Tìm trong tài liệu provider:
  Docker volume → identify bằng **name**; Docker container → identify bằng
  **full container ID** (xem `docker inspect --format '{{.Id}}'`).
- `terraform import` đẩy resource vào state nhưng KHÔNG sinh ra config. Bạn
  phải tự viết resource block. Cú pháp 2 cái phải khớp nhau (cùng địa chỉ).
- Sau import, `terraform plan` sẽ có diff — đó là chuyện BÌNH THƯỜNG. Lý do?
  Provider default schema khác giá trị thật của container. Tự xử lý từng diff.
- Lệnh nào giúp bạn nhìn state thực tế của resource vừa import?
  (Hint: `terraform state show`.)

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Thứ tự thao tác chuẩn:**

```
1. setup.sh                          (tạo legacy resource ngoài TF)
2. cd starter && terraform init
3. Viết resource block ESTIMATE      (chưa cần đúng 100%)
4. terraform import VOLUME           (volume ID = name)
5. terraform import CONTAINER        (container ID = docker inspect .Id)
6. terraform state show <addr>       (đọc live truth)
7. Tinh chỉnh main.tf đến khi plan = 0 changes
8. terraform apply                   (no-op refresh)
```

**Lấy ID Docker:**

```bash
# Container — phải dùng full ID, không phải tên:
docker inspect --format '{{.Id}}' tflab-07-legacy-app

# Volume — dùng name:
echo tflab-07-legacy-data
```

**Cấu trúc resource block tối thiểu:**

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_volume" "legacy_data" {
  name = "tflab-07-legacy-data"
}

resource "docker_container" "legacy_app" {
  name  = "tflab-07-legacy-app"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8110
  }

  volumes {
    volume_name    = docker_volume.legacy_data.name
    container_path = "/var/data"
  }

  # … và thêm các attribute để đóng diff sau khi plan ...
}
```

**Khi plan vẫn có diff sau import:**

1. Đọc dòng diff đầu tiên — Terraform sẽ in dạng `~ attribute = "default" -> "real_value"`.
2. Thêm attribute đó vào block với value `"real_value"`.
3. `terraform plan` lại.
4. Lặp đến khi `No changes`.

**Lệnh import chính xác:**

```bash
terraform import docker_volume.legacy_data tflab-07-legacy-data
terraform import docker_container.legacy_app "$(docker inspect --format '{{.Id}}' tflab-07-legacy-app)"
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**Skeleton hoàn chỉnh cho `main.tf`** (phần xương sống — thiếu 1-2 attribute
mà bạn phải tự thêm sau khi đọc `terraform state show`):

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_volume" "legacy_data" {
  name = "tflab-07-legacy-data"
}

resource "docker_container" "legacy_app" {
  name  = "tflab-07-legacy-app"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8110
  }

  volumes {
    volume_name    = docker_volume.legacy_data.name
    container_path = "/var/data"
  }

  restart      = "unless-stopped"   # set from `docker run --restart unless-stopped`
  must_run     = true               # container is running
  network_mode = "bridge"           # Docker default; provider would show diff if omitted
  log_driver   = "json-file"        # ← TỰ KIỂM TRA bằng `terraform state show`
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):**

> Vì sao import KHÔNG sinh config? Đây là design choice hay limit?

Design choice. HashiCorp giữ import minimal để không "đoán" cấu trúc HCL bạn
muốn — bạn có thể muốn dùng `for_each`, hay tách module, hay nhóm với resource
khác. `import {}` block + `-generate-config-out` (lab 08) có sinh config,
nhưng cũng cảnh báo "best-effort, cần refactor".

> Nếu tôi `terraform import` 2 lần cùng địa chỉ thì sao?

Lần 2 sẽ lỗi: `Resource already managed by Terraform`. Phải `terraform state rm`
trước khi import lại.

> Sau khi import xong, tôi `terraform destroy` rồi `terraform apply` lại có
> ra container giống hệt không?

KHÔNG đảm bảo. `destroy` xoá container thật (kể cả volume nếu config sai).
Container ID sẽ khác (Docker random ID mới). IP container đổi. Mọi container
khác link tới nó qua ID sẽ vỡ. Đây là LÝ DO ta import thay vì destroy/recreate.

> `terraform plan -refresh=false` khác `terraform plan` chỗ nào sau import?

`plan` (mặc định) sẽ refresh state từ live trước khi so với config. Sau import
config + state đã khớp nên dù refresh hay không, kết quả nên là 0 changes.
Plan với `-refresh=false` mà vẫn 0 changes → bằng chứng config thực sự đại
diện cho live (không phải refresh "che" diff).

</details>
