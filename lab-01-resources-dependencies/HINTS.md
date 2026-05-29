# Hints — Lab 01

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- "Container X cần Container Y khởi động trước" — Terraform có **hai cách** để diễn đạt:
  - *Implicit*: viết một biểu thức trong X tham chiếu tới attribute của Y. Có reference =
    có edge trong graph.
  - *Explicit*: dùng `depends_on = [Y]` khi không có reference nào.
- Trong lab này: container `db` được container `web` "depend" theo nghĩa nghiệp vụ, nhưng web
  KHÔNG đọc attribute nào của db → cách nào là đúng?
- Image gắn vào container thế nào để Terraform biết "container cần image build xong trước"?
  Hint: `image_id`.
- Network gắn vào container qua block nào? Tra docs `docker_container` → tìm
  `networks_advanced`.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Bố cục resource cần xây:**

```
docker_network.app
   ↑ (reference qua networks_advanced)
   │
   ├── docker_container.db ──── tham chiếu docker_image.redis.image_id
   │
   └── docker_container.web ─── tham chiếu docker_image.nginx.image_id
                                + depends_on = [docker_container.db]
                                + ports { internal=80, external=8081 }
```

**Khung gợi ý cho web:**

```hcl
resource "docker_container" "web" {
  name  = "<tên theo README>"
  image = <reference tới docker_image.nginx.image_id>

  networks_advanced {
    name = <reference tới docker_network.app.name>
  }

  ports {
    internal = <cổng nginx>
    external = <cổng host theo README>
  }

  restart = "unless-stopped"

  depends_on = [<resource address của db>]
}
```

**Outputs:**

- `containers` là *list* các string. Cú pháp: `value = [resource1.name, resource2.name]`.
- Quan sát: liệt kê `web` trước hay `db` trước? README có quy định không? (Không — nhưng bạn
  nên có lựa chọn nhất quán; solution dùng `[web, db]`.)

**Khi nào `terraform plan` báo "replace"?**

Sau khi apply lần 1, thử đổi `external = 8081` → `9999` rồi `terraform plan`. Bạn sẽ thấy ký hiệu
`-/+` — đó là *replace*, vì cổng là ForceNew.

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

```hcl
resource "docker_network" "app" {
  name = "tflab-01-net"
}

resource "docker_image" "redis" {
  name         = "redis:7-alpine"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "db" {
  name  = "tflab-01-db"
  image = docker_image.redis.image_id

  networks_advanced {
    name = docker_network.app.name
  }

  restart = "unless-stopped"
}

resource "docker_container" "web" {
  name  = "tflab-01-web"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.app.name
  }

  ports {
    internal = 80
    external = 8081
  }

  restart = "unless-stopped"

  depends_on = [docker_container.db]
}
```

```hcl
# outputs.tf
output "network_id" {
  description = "..."
  value       = docker_network.app.id
}

output "web_url" {
  description = "..."
  value       = "http://localhost:8081"
}

output "containers" {
  description = "..."
  value       = [docker_container.web.name, docker_container.db.name]
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):** Nếu tôi xoá `depends_on` đi, lab vẫn pass `verify.sh`
chứ? — Có thể! Vì verify chỉ kiểm tra trạng thái *cuối*, không kiểm tra thứ tự khởi động.
Nhưng RUBRIC chấm điểm cao cho người **biết khi nào cần** `depends_on`, dù bạn không thấy hậu
quả trên local. Trong thực tế (cloud, IAM, hoặc app phụ thuộc DB) — thiếu `depends_on` sẽ apply
fail trên CI.

</details>
