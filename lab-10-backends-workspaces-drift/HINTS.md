# Hints — Lab 10

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `backend "local" {}` là 1 block rỗng — không cần attribute nào, chỉ cần
  khai báo. Đặt **bên trong** block `terraform { ... }`.
- `terraform.workspace` là tên workspace hiện tại (string). Sử dụng giống
  như biến thường: `name = "tflab-10-${terraform.workspace}"`.
- `count` cộng với `count.index` (0-based) ra số replica. Để hiển thị
  1-based trong tên, dùng `count.index + 1`.
- `local.cfg` map có 2 field: `port` (number) và `replicas` (number).
  Truy cập: `local.cfg.port`, `local.cfg.replicas`.
- `labels { ... }` là **block lồng** trong `docker_container`, không phải
  attribute. Mỗi label = 1 block.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**`versions.tf` (chỉ phần backend):**

```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }

  backend "local" {}    # ← THÊM DÒNG NÀY
}
```

**`main.tf` (resource container):**

```hcl
resource "docker_container" "app" {
  count = local.cfg.replicas

  name  = "tflab-10-${terraform.workspace}-${count.index + 1}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = local.cfg.port + count.index
  }

  labels {
    label = "tflab.workspace"
    value = terraform.workspace
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}
```

**`outputs.tf` (urls và container_ids):**

```hcl
output "urls" {
  value = [for c in docker_container.app : "http://localhost:${c.ports[0].external}"]
}

output "container_ids" {
  value = [for c in docker_container.app : c.id]
}
```

**Quy trình deploy 2 workspace:**

```
terraform init                       # đọc backend mới
terraform workspace new dev          # tạo + select dev
terraform apply                      # → 1 container :8201
terraform workspace new prod         # tạo + select prod
terraform apply                      # → 2 container :8202, :8203
terraform workspace list             # confirm dev và prod đều có
```

**Cần `terraform init` lần nữa không khi đổi workspace?** KHÔNG. Workspace
là layer trên cùng backend, init chỉ cần khi backend block thay đổi.

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**File `versions.tf` hoàn chỉnh:**

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  backend "local" {}
}

provider "docker" {}
```

**File `main.tf` hoàn chỉnh:**

```hcl
locals {
  cfg = lookup(var.workspace_config, terraform.workspace, var.workspace_config["default"])
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  count = local.cfg.replicas

  name  = "tflab-10-${terraform.workspace}-${count.index + 1}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = local.cfg.port + count.index
  }

  labels {
    label = "tflab.workspace"
    value = terraform.workspace
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):**

> Apply vào workspace `default` thì sao?

`local.cfg = workspace_config["default"]` → port 8200, replicas=1, container
tên `tflab-10-default-1`. Lab không yêu cầu — bạn có thể bỏ qua hoặc demo.

> Tại sao dùng `count` thay vì `for_each`?

Vì replicas là số nguyên đơn giản, không có "tên" riêng cho mỗi instance.
`count` cho phép dùng `count.index` cộng vào port. Nếu mỗi replica có
config khác nhau (vd: memory limit), `for_each` map sẽ hợp lý hơn.

> Tôi `terraform workspace new prod` trước `dev`. OK không?

OK. Workspaces độc lập, thứ tự không quan trọng.

> Tôi muốn 3 workspaces: dev, staging, prod. Phải làm gì?

Thêm `staging = { port = 8204, replicas = 1 }` vào default value của
`workspace_config` trong `variables.tf`. Không cần đổi code khác.

> Vì sao port dùng `local.cfg.port + count.index`?

Tránh port collision khi cùng máy chạy nhiều replica của cùng workspace.
prod replicas=2 → port 8202 (count.index=0) và 8203 (count.index=1).
Nếu chỉ `local.cfg.port` cho mọi index → 2 container chiếm cùng port 8202
→ container thứ 2 fail to start.

> Drift A: tôi `docker stop` rồi `terraform plan` báo "1 to change", không
> phải "1 to replace". Tại sao?

`must_run = true` là attribute KHÔNG force-replacement. Terraform sẽ
**start** lại container (in-place change). Nếu set `must_run = false`,
Terraform chấp nhận container stopped → plan no-op.

> Drift B sau `apply -refresh-only`: tôi expect Terraform xoá label
> "manual=true". Sao plan vẫn báo "1 to change"?

`-refresh-only` chỉ cập nhật state để biết về label. Config (.tf) không
có label "manual" → diff vẫn còn. Để remove drift, hoặc:
1. `terraform apply` (không `-refresh-only`) → Terraform xoá label.
2. Hoặc thêm `manual = true` vào labels block → drift gone, accept config.

</details>
