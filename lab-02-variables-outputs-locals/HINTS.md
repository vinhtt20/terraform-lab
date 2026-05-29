# Hints — Lab 02

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `validation {}` block phải nằm **bên trong** `variable {}`, không phải ngoài. Một `variable`
  có thể có **nhiều** `validation` block (mỗi block 1 rule).
- `condition` trong `validation` chỉ được tham chiếu **chính biến đó** (`var.<name>`), không
  được tham chiếu biến khác. Lý do: validation chạy lúc parse biến.
- Pattern "nếu user không truyền thì sinh ngẫu nhiên" thường dùng `count = X == null ? 1 : 0`
  trên `random_password`, sau đó `coalesce(var.X, try(resource[0].result, null))`.
- `dynamic` block: tra docs `docker_container.labels` để xem nó là block (lặp được) hay
  attribute. Câu trả lời nằm ở dòng "Nested Schema for `labels`" trong docs.
- Tự hỏi: `terraform output password` vs `terraform output -raw password` — output nào trả về
  giá trị thật?

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**`validation` block — cú pháp chuẩn:**

```hcl
variable "x" {
  type = number
  default = 5

  validation {
    condition     = var.x >= 1 && var.x <= 10
    error_message = "x phải trong [1,10], nhận được ${var.x}."
  }
}
```

Lưu ý: dùng `can(...)` để bọc regex nếu giá trị có thể null, hoặc dùng `regex()` trực tiếp khi
chắc chắn non-null.

**Pattern `coalesce(var.x, try(resource[0].y, null))`:**

```hcl
locals {
  password_effective = coalesce(
    var.admin_password,                              # 1. user-provided
    try(random_password.admin[0].result, null),     # 2. fallback to generated
  )
}
```

`try(...)` cần thiết vì khi `var.admin_password != null`, `random_password.admin` có
`count = 0` — index `[0]` không tồn tại. `try()` nuốt lỗi và trả `null`, để `coalesce` chọn
giá trị đầu tiên non-null.

**`for_each` với key string:**

```hcl
resource "docker_container" "app" {
  for_each = toset([for i in range(var.replicas) : tostring(i)])

  name = "${local.container_name_prefix}-${each.key}"
  ports {
    external = var.external_port_base + tonumber(each.key)
    internal = 80
  }
}
```

Vì sao `tostring(i)`? Vì `toset(range(N))` cho ra set of numbers — Terraform vẫn nhận, nhưng
`each.key` sẽ là **string** (set keys luôn là string). Convert tường minh giúp code rõ hơn.

**`dynamic` cho labels:**

```hcl
dynamic "labels" {
  for_each = local.merged_labels
  content {
    label = labels.key      # tên block lặp là "labels", nên iterator tên "labels"
    value = labels.value
  }
}
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

```hcl
# variables.tf
variable "image" {
  type    = object({ name = string, tag = string })
  default = { name = "nginx", tag = "1.27-alpine" }

  validation {
    condition     = var.image.tag != "latest"
    error_message = "image.tag must be pinned, got 'latest'."
  }
}

variable "service_name" {
  type    = string
  default = "demo"

  validation {
    condition     = length(var.service_name) >= 3 && length(var.service_name) <= 32
    error_message = "service_name length must be [3,32], got ${length(var.service_name)}."
  }
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "service_name must match ^[a-z0-9-]+$, got '${var.service_name}'."
  }
}

variable "admin_password" {
  type      = string
  default   = null
  sensitive = true
}
```

```hcl
# main.tf
resource "random_password" "admin" {
  count   = var.admin_password == null ? 1 : 0
  length  = 20
  special = true
}

resource "docker_container" "app" {
  for_each = toset([for i in range(var.replicas) : tostring(i)])

  name  = "${local.container_name_prefix}-${each.key}"
  image = docker_image.app.image_id

  ports {
    internal = 80
    external = var.external_port_base + tonumber(each.key)
  }

  dynamic "labels" {
    for_each = local.merged_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "local_file" "summary" {
  filename = "${path.module}/summary.json"
  content = jsonencode({
    service = var.service_name
    image   = "${var.image.name}:${var.image.tag}"
    names   = [for c in docker_container.app : c.name]
    ports   = [for c in docker_container.app : tolist(c.ports)[0].external]
    labels  = local.merged_labels
  })
}
```

```hcl
# outputs.tf
output "password" {
  value     = local.password_effective
  sensitive = true                       # KHÔNG quên đánh dấu này
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):** Nếu tôi đặt `TF_VAR_replicas=10` rồi
`terraform plan -var replicas=3`, Terraform sẽ dùng `3` hay `10`? — `3`, vì `-var` có ưu tiên
cao hơn `TF_VAR_*` (xem bảng trong README "Đào sâu"). Nhưng `replicas=10` cũng sẽ trượt
`validation` (max 5).

</details>
