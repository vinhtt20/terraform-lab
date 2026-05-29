# Hints — Lab 11

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `validation {}` đặt **bên trong** block `variable {}`. Mỗi variable có
  thể có nhiều validation block.
- `condition` PHẢI trả về `bool`. Tham chiếu giá trị qua `var.<name>`
  (chính variable đang validate).
- `precondition`/`postcondition` đặt **bên trong** `lifecycle {}` block,
  cùng level với `ignore_changes`.
- `self.image_id` chỉ available **sau** khi resource được tạo
  (postcondition), không phải trước (precondition).
- `check {}` block là **top-level** — đặt ngoài mọi resource. Tên block
  giống resource: `check "name" { assert { ... } }`.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Validation regex (variables.tf):**

```hcl
variable "name_prefix" {
  type    = string
  default = "tflab-11"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name_prefix))
    error_message = "name_prefix must start with lowercase letter and contain only [a-z0-9-], length 3..31."
  }
}
```

**Validation range:**

```hcl
variable "base_port" {
  type    = number
  default = 8221

  validation {
    condition     = var.base_port >= 8000 && var.base_port <= 9999
    error_message = "base_port must be in [8000, 9999]."
  }
}
```

**Precondition + postcondition trong resource:**

```hcl
resource "docker_container" "app" {
  # ... (count, name, image, ports, restart, must_run)

  lifecycle {
    precondition {
      condition     = (var.base_port + count.index) < 10000
      error_message = "Port (base_port + count.index) must remain under 10000."
    }
    postcondition {
      condition     = length(self.ports) > 0 && self.ports[0].external == (var.base_port + count.index)
      error_message = "Container did not bind the expected external port."
    }
    ignore_changes = [log_opts]
  }
}
```

**Check block (top-level):**

```hcl
check "unique_ports" {
  assert {
    condition     = length(distinct([for c in docker_container.app : c.ports[0].external])) == length(docker_container.app)
    error_message = "External ports of containers must be unique."
  }
}
```

**Test validation hoạt động:**

```bash
terraform plan -var "base_port=80"
# Mong đợi: "Error: Invalid value for variable"
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**`variables.tf` hoàn chỉnh:**

```hcl
variable "name_prefix" {
  type    = string
  default = "tflab-11"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name_prefix))
    error_message = "name_prefix must start with a lowercase letter and contain only [a-z0-9-], length 3..31."
  }
}

variable "base_port" {
  type    = number
  default = 8221

  validation {
    condition     = var.base_port >= 8000 && var.base_port <= 9999
    error_message = "base_port must be in [8000, 9999]."
  }
}

variable "replicas" {
  type    = number
  default = 2

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 5
    error_message = "replicas must be in [1, 5]."
  }
}
```

**`main.tf` hoàn chỉnh:**

```hcl
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true

  lifecycle {
    postcondition {
      condition     = self.image_id != ""
      error_message = "Image must have a resolved image_id after pull."
    }
  }
}

resource "docker_container" "app" {
  count = var.replicas

  name  = "${var.name_prefix}-${count.index + 1}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.base_port + count.index
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    precondition {
      condition     = (var.base_port + count.index) < 10000
      error_message = "Port (base_port + count.index) must remain under 10000."
    }
    postcondition {
      condition     = length(self.ports) > 0 && self.ports[0].external == (var.base_port + count.index)
      error_message = "Container did not bind the expected external port."
    }
    ignore_changes = [log_opts]
  }
}

check "unique_ports" {
  assert {
    condition     = length(distinct([for c in docker_container.app : c.ports[0].external])) == length(docker_container.app)
    error_message = "External ports of containers must be unique."
  }
}
```

**Câu hỏi tự kiểm:**

> Vì sao có cả precondition VÀ postcondition cho cùng resource?

Khác mục đích. Precondition kiểm "input/cross-resource sane" trước khi
attempt action; postcondition kiểm "provider/network behaved" sau action.
Vd: precondition đảm bảo port trong range hợp lệ; postcondition đảm bảo
provider thực sự bound đúng port đó (catch provider bug).

> Tôi đặt `condition = self.id != ""` trong precondition. Vì sao Terraform
> báo lỗi?

`self` trong precondition là pre-create — `id` chưa known. Move check sang
postcondition.

> `check "x" { assert { ... } }` fail. Apply có dừng không?

KHÔNG. Check block là best-effort, fail → warning. Apply tiếp tục. Nếu bạn
muốn fail-hard, dùng `precondition`/`postcondition` thay vào.

> Validation regex dài quá. Tôi muốn split thành 2 validation block. OK không?

OK. Mỗi variable có thể có **nhiều** validation block — kiểm từng aspect
riêng. Error message rõ hơn cho user.

```hcl
validation {
  condition     = length(var.name_prefix) >= 3
  error_message = "name_prefix must be at least 3 characters."
}
validation {
  condition     = can(regex("^[a-z]", var.name_prefix))
  error_message = "name_prefix must start with lowercase letter."
}
```

> `-var "base_port=80"` apply qua được? Validation đâu rồi?

Check: bạn đã thêm `validation` block CHƯA? Validation chỉ chạy nếu
khai báo. Cũng check syntax: `condition` trả về bool, không phải string.

</details>
