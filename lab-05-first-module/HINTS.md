# Hints — Lab 05

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- Module child cần file `versions.tf` chứa GÌ và KHÔNG chứa GÌ? Đọc CONVENTIONS §4 và §8.
- Khi cần "tạo resource X chỉ khi flag Y bật", `count = Y ? 1 : 0` là pattern chuẩn.
  Nhưng làm sao reference index `[0]` an toàn trong output? Gợi ý: `try()`.
- `dynamic "volumes"` của `docker_container` — mỗi block volumes bên trong content
  dùng key gì? `host_path` cho bind-mount, `volume_name` cho named volume.
- `path.module` vs `path.root` — khác nhau khi nào? Đọc <https://developer.hashicorp.com/terraform/language/expressions/references#filesystem-and-workspace-info>.
- Output `url` của module và output `urls` của root khác nhau như thế nào? (Hint: 1 là per-call, 1 là aggregate.)

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Cấu trúc thư mục cuối cùng**:

```
starter/
├── versions.tf, variables.tf, main.tf, outputs.tf
├── templates/frontend.html.tftpl
└── modules/web_service/
    ├── versions.tf       # CHỈ required_providers — KHÔNG provider {}
    ├── variables.tf      # name, image, external_port, labels, index_content, enable_log_volume
    ├── main.tf           # docker_image + docker_container + count-gated local_file & docker_volume
    ├── outputs.tf        # container_id, name, url, volume_name (qua try())
    └── README.md
```

**Conditional resource bên trong module**:

```hcl
resource "local_file" "index" {
  count    = var.index_content == null ? 0 : 1
  filename = "${path.module}/rendered/${var.name}.html"
  content  = var.index_content
}
```

**Dynamic mount HTML (chỉ khi index_content != null)**:

```hcl
dynamic "volumes" {
  for_each = var.index_content == null ? [] : [1]
  content {
    host_path      = abspath(local_file.index[0].filename)
    container_path = "/usr/share/nginx/html/index.html"
    read_only      = true
  }
}
```

`for_each = []` → block không render. `[1]` → render 1 lần. Đây là idiom chuẩn để
toggle dynamic block.

**Output an toàn cho resource conditional**:

```hcl
output "volume_name" {
  value = try(docker_volume.logs[0].name, null)
}
```

Khi `enable_log_volume = false`, `docker_volume.logs` không có index `[0]` → `try()` nuốt
lỗi, trả `null`. Caller (`module.frontend.volume_name`) thấy `null` là OK.

**Gọi module với templatefile()**:

```hcl
module "frontend" {
  source = "./modules/web_service"

  name              = "frontend"
  image             = var.image
  external_port     = 8094
  enable_log_volume = true

  index_content = templatefile("${path.module}/templates/frontend.html.tftpl", {
    title    = "tflab-05 Frontend"
    build_id = random_id.build.hex
  })

  labels = { role = "frontend", tier = "web" }
}
```

`path.module` ở root = thư mục `starter/`. Template ở `starter/templates/...`.

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**`modules/web_service/variables.tf`:**

```hcl
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "name must match ^[a-z0-9-]+$, got '${var.name}'."
  }
  validation {
    condition     = length(var.name) >= 2 && length(var.name) <= 32
    error_message = "name length must be in [2, 32], got ${length(var.name)}."
  }
}

variable "image" {
  type = string
  validation {
    condition     = !endswith(var.image, ":latest")
    error_message = "image tag must not be 'latest', got '${var.image}'."
  }
}

variable "external_port" {
  type = number
  validation {
    condition     = var.external_port >= 1 && var.external_port <= 65535
    error_message = "external_port must be in [1, 65535], got ${var.external_port}."
  }
}

variable "labels"            { type = map(string), default = {} }
variable "index_content"     { type = string,      default = null }
variable "enable_log_volume" { type = bool,        default = false }
```

(`,` thừa ở trên là cho dễ đọc — HCL không cho phép `,` ngoài map/list literals. Trong
thực tế viết mỗi attribute trên 1 dòng.)

**`modules/web_service/main.tf`:**

```hcl
locals {
  container_name = "tflab-05-${var.name}"
  effective_labels = merge(
    { managed_by = "terraform", service = var.name },
    var.labels,
  )
}

resource "docker_image" "this" {
  name         = var.image
  keep_locally = true
}

resource "local_file" "index" {
  count    = var.index_content == null ? 0 : 1
  filename = "${path.module}/rendered/${var.name}.html"
  content  = var.index_content
}

resource "docker_volume" "logs" {
  count = var.enable_log_volume ? 1 : 0
  name  = "${local.container_name}-logs"
}

resource "docker_container" "this" {
  name  = local.container_name
  image = docker_image.this.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  dynamic "volumes" {
    for_each = var.index_content == null ? [] : [1]
    content {
      host_path      = abspath(local_file.index[0].filename)
      container_path = "/usr/share/nginx/html/index.html"
      read_only      = true
    }
  }

  dynamic "volumes" {
    for_each = var.enable_log_volume ? [1] : []
    content {
      volume_name    = docker_volume.logs[0].name
      container_path = "/var/log/nginx"
    }
  }

  dynamic "labels" {
    for_each = local.effective_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  restart = "unless-stopped"
}
```

**Root `main.tf`** (module "frontend"):

```hcl
module "frontend" {
  source = "./modules/web_service"

  name              = "frontend"
  image             = var.image
  external_port     = 8094
  enable_log_volume = true

  index_content = templatefile("${path.module}/templates/frontend.html.tftpl", {
    title    = "tflab-05 Frontend"
    build_id = random_id.build.hex
  })

  labels = { role = "frontend", tier = "web" }
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):**

> Tôi đổi `enable_log_volume` từ `true` về `false`. `terraform plan` sẽ làm gì?

Sẽ destroy `docker_volume.logs[0]` (vì count chuyển 1 → 0) và update container để bỏ mount
volumes block. Dữ liệu trong volume sẽ mất. Trong production phải có `lifecycle { prevent_destroy = true }`
hoặc dùng `removed {}` block (lab 09).

> Vì sao module chỉ khai báo `required_providers` mà KHÔNG cần `provider "docker" {}`?

Vì provider configuration là responsibility của root module. Module con chỉ tuyên bố
"tôi cần provider tên `docker` từ source này, version trong range này" — root cấp
configuration thực. Đặt `provider {}` trong module con sẽ khoá module vào 1 cấu hình
duy nhất, mất khả năng tái sử dụng (xem README "Đào sâu").

</details>
