# Hints — Lab 03

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `for_each` chấp nhận **map** hoặc **set of strings**. Khi truyền map, `each.key` là key của
  map, `each.value` là object.
- Đọc lại docs `docker_container`: phân biệt `env` (set of strings, `KEY=VAL`) và `volumes`
  (block lặp được).
- `templatefile()` cần path tương đối `path.module`. File không tìm thấy = lỗi rõ ràng khi
  plan.
- `dynamic` block trên/tắt: `for_each = condition ? [1] : []` — list 1 phần tử ⇒ block xuất
  hiện 1 lần; list rỗng ⇒ block biến mất.
- `plantimestamp()` cho ra string RFC3339. Nó **thay đổi mỗi plan** — bạn cần `ignore_changes`
  ở chỗ nào dùng nó như attribute resource.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Biến `services` default:**

```hcl
default = {
  alpha = {
    image         = "nginx:1.27-alpine"
    external_port = 8083
    env           = { ROLE = "frontend", TEAM = "alpha" }
  }
  bravo = {
    image         = "nginx:1.27-alpine"
    external_port = 8084
    env           = { ROLE = "api", TEAM = "bravo" }
  }
  charlie = {
    image              = "nginx:1.27-alpine"
    external_port      = 8085
    env                = { ROLE = "worker", TEAM = "charlie" }
    enable_healthcheck = false      # cho phép test path "tắt healthcheck"
  }
}
```

**locals.service_labels — for-expression build map of maps:**

```hcl
service_labels = {
  for k, _ in var.services : k => merge(var.global_labels, { service = k })
}
```

Dấu `_` là quy ước cho "không dùng giá trị" (giống Python).

**Mount HTML vào container:**

```hcl
volumes {
  host_path      = abspath(local_file.html[each.key].filename)
  container_path = "/usr/share/nginx/html/index.html"
  read_only      = true
}
```

**Dynamic healthcheck:**

```hcl
dynamic "healthcheck" {
  for_each = each.value.enable_healthcheck ? [1] : []
  content {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }
}
```

**Template syntax cho HTML:**

```
%{ for k, v in env ~}
  <li>${k} = ${v}</li>
%{ endfor ~}
```

Dấu `~` strip whitespace 2 bên — giúp file output gọn.

**Output `urls` map:**

```hcl
value = {
  for k, v in var.services : k => "http://localhost:${v.external_port}"
}
```

**Output `container_names` sorted by key:**

```hcl
value = [for k in sort(keys(var.services)) : docker_container.app[k].name]
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

```hcl
# main.tf
locals {
  rendered_at = plantimestamp()
  service_labels = {
    for k, _ in var.services : k => merge(var.global_labels, { service = k })
  }
}

resource "local_file" "html" {
  for_each = var.services

  filename = "${path.module}/html/${each.key}.html"
  content = templatefile("${path.module}/templates/index.html.tftpl", {
    name        = each.key
    port        = each.value.external_port
    env         = each.value.env
    rendered_at = local.rendered_at
  })

  lifecycle {
    ignore_changes = [content]   # rendered_at đổi mỗi plan → ignore để idempotent
  }
}

resource "docker_container" "app" {
  for_each = var.services

  name  = "tflab-03-${each.key}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = each.value.external_port
  }

  env = [for k, v in each.value.env : "${k}=${v}"]

  volumes {
    host_path      = abspath(local_file.html[each.key].filename)
    container_path = "/usr/share/nginx/html/index.html"
    read_only      = true
  }

  dynamic "healthcheck" {
    for_each = each.value.enable_healthcheck ? [1] : []
    content {
      test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
      interval = "10s"
    }
  }

  dynamic "labels" {
    for_each = local.service_labels[each.key]
    content {
      label = labels.key
      value = labels.value
    }
  }

  restart = "unless-stopped"
}
```

**Câu hỏi tự kiểm:** Nếu tôi đổi `for_each` thành `count = length(var.services)` thì sao? —
Thì `each.key` không còn (phải dùng `count.index`), và bạn không còn cách "tự nhiên" để lấy
config của service N. Tệ hơn: thêm service "delta" vào đầu map → tất cả index dịch → tất cả
container bị destroy-recreate. Đó là lý do `for_each` thắng `count` trong 95% trường hợp
manage nhiều resource có cấu hình khác nhau.

</details>
