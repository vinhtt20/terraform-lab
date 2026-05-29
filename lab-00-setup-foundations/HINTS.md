# Hints — Lab 00

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- Trong file `main.tf`, hai resource đã có sẵn nhưng giá trị là `"PLACEHOLDER..."`. Nhiệm vụ của
  bạn là **đổi chuỗi placeholder** thành giá trị đúng — không tạo resource mới, không xoá block.
- Hai resource phải "nối" được với nhau: container biết dùng image nào? Câu trả lời nằm ở
  attribute `image_id` của resource `docker_image.nginx`.
- Trong `outputs.tf`, value của output có thể là biểu thức tham chiếu attribute — không phải
  chỉ chuỗi cứng.
- Câu hỏi tự kiểm: "Nếu tôi đổi `external = 8080` thành `8081`, `terraform plan` sẽ báo
  update-in-place hay replace?" (Trả lời ở Bậc 3.)

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Cấu trúc tổng quan của hai resource:**

```hcl
resource "docker_image" "nginx" {
  name         = "<image_name_với_tag>"
  keep_locally = true
}

resource "docker_container" "hello" {
  name  = "<tên container theo yêu cầu README>"
  image = <reference tới image_id ở resource trên>

  ports {
    internal = <cổng nginx lắng nghe bên trong container>
    external = <cổng host cần map ra>
  }

  restart = "<policy nào để container tự khởi động lại>"
}
```

**Outputs:**

- `value` của một output có thể là **biểu thức** tham chiếu attribute resource khác. Ví dụ
  `value = some_resource.id`. Tra cứu `docker_container` schema để biết attribute chính xác.
- Output `url` chỉ là chuỗi cố định — không phải tham chiếu, vì port là hằng số 8080 ở lab này.

**Lưu ý formatting:**

- Sau khi sửa xong, chạy `terraform fmt` để Terraform tự căn lề (đặc biệt block `ports`).
- `terraform validate` sẽ báo nếu thiếu attribute bắt buộc — đọc kỹ thông báo lỗi, nó chỉ rõ
  dòng và lý do.

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

```hcl
# main.tf
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"   # tag cố định, KHÔNG dùng "latest"
  keep_locally = true
}

resource "docker_container" "hello" {
  name  = "tflab-00-hello"
  image = docker_image.nginx.image_id  # NỐI hai resource ở đây

  ports {
    internal = 80                       # cổng nginx mặc định
    external = 8080                     # cổng host
  }

  restart = "unless-stopped"
}
```

```hcl
# outputs.tf
output "container_id" {
  description = "Full Docker container ID of the nginx instance."
  value       = docker_container.hello.id
}

output "url" {
  description = "URL where the running nginx container can be reached."
  value       = "http://localhost:8080"
}
```

**Trả lời câu hỏi ở Bậc 1:** Đổi `external = 8081` sẽ **replace container** (recreate), không
phải update-in-place — vì port mapping của Docker provider gắn vào container ID, không sửa được
sống. Bạn sẽ học chi tiết hơn ở Lab 01 và Lab 12 (`replace_triggered_by`).

</details>
