# Module `web_service`

Một module nhỏ đóng gói "1 service nginx có cấu hình chuẩn": image + container,
labels, optional custom index.html, optional named log volume.

## Yêu cầu

- Terraform `>= 1.9.0`.
- Providers (do **root module** truyền vào — không khai báo `provider {}` ở đây):
  - `kreuzwerker/docker ~> 3.0`
  - `hashicorp/local ~> 2.5`

## Inputs

| Tên | Kiểu | Bắt buộc | Default | Mô tả |
|-----|------|----------|---------|-------|
| `name` | `string` | ✅ | — | Tên service (DNS-safe `^[a-z0-9-]+$`, độ dài 2–32). Dùng làm suffix tên container. |
| `image` | `string` | ✅ | — | Image kèm tag, KHÔNG được `:latest`. Ví dụ `nginx:1.27-alpine`. |
| `external_port` | `number` | ✅ | — | Cổng host bind vào cổng 80 của container. `1 <= x <= 65535`. |
| `labels` | `map(string)` | ❌ | `{}` | Labels bổ sung. Module tự thêm `managed_by=terraform` và `service=<name>`. |
| `index_content` | `string` | ❌ | `null` | Nội dung HTML để serve làm `/index.html`. `null` → giữ trang mặc định của image. |
| `enable_log_volume` | `bool` | ❌ | `false` | Tạo named volume Docker và mount vào `/var/log/nginx`. |

## Outputs

| Tên | Mô tả |
|-----|-------|
| `container_id` | Docker container ID. |
| `name` | Tên container (khớp `docker ps`). |
| `url` | URL truy cập trên host: `http://localhost:<external_port>`. |
| `volume_name` | Tên log volume khi `enable_log_volume = true`; ngược lại `null`. |

## Ví dụ sử dụng (gọi từ root)

```hcl
module "api" {
  source = "./modules/web_service"

  name          = "api"
  image         = "nginx:1.27-alpine"
  external_port = 8093

  labels = {
    role = "backend"
  }
}

module "frontend" {
  source = "./modules/web_service"

  name              = "frontend"
  image             = "nginx:1.27-alpine"
  external_port     = 8094
  enable_log_volume = true

  index_content = templatefile("${path.module}/templates/index.html.tftpl", {
    title = "Frontend"
  })
}
```

## Ghi chú

- Module **không** khai báo `provider "docker" {}` — đó là trách nhiệm của root module
  (best practice; xem README lab "Đào sâu" để biết vì sao).
- Đường dẫn source nên là tương đối (`./modules/...`) hoặc git/registry — KHÔNG dùng
  đường dẫn tuyệt đối (`/Users/...`).
- Để generate bảng input/output tự động, có thể dùng [`terraform-docs`](https://terraform-docs.io/).
