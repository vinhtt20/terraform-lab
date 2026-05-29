# Hints — Lab 06

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- Muốn deploy cùng 1 module vào 2 "region" khác nhau, bạn cần gì ở **root**?
  (Hint: 2 `provider "docker"` block — 1 default, 2 alias.)
- Bên trong **module con**, làm sao tuyên bố "tôi sẽ dùng 1 provider alias do caller truyền vào"?
  (Hint: tra docs `configuration_aliases`.)
- `for_each` trên `module` block có hợp lệ không? Có. Cú pháp giống `for_each` trên resource:
  `for_each = local.services`, dùng `each.key`, `each.value` trong module call.
- Nhưng `providers = { ... }` của module có dùng `each.value` được KHÔNG? **Không** — providers
  phải static. Đó là lý do bạn cần 2 module call khác nhau cho 2 region.
- Port collision: nếu 2 replica của cùng 1 service bind vào `external_port`, sẽ lỗi "address
  in use". Module phải offset port theo replica index.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Cấu trúc thư mục cuối**:

```
starter/
├── versions.tf        # docker + random; default + 2 alias east/west
├── main.tf            # locals.services + 3 module call (network, service_east, service_west)
├── outputs.tf         # network_id + services_east/west + container_names
└── modules/
    ├── network/
    │   ├── versions.tf       # required_providers docker (no alias)
    │   ├── variables.tf      # name, labels
    │   ├── main.tf           # docker_network with dynamic labels
    │   ├── outputs.tf        # id, name
    │   └── README.md
    └── service/
        ├── versions.tf       # configuration_aliases = [docker.target]
        ├── variables.tf      # name, image, external_port, network_name, replicas, labels, healthcheck
        ├── main.tf           # docker_image + docker_container with for_each + provider=docker.target
        ├── outputs.tf        # container_names, urls, image_id, replicas
        └── README.md
```

**Khai báo configuration_aliases trong module service:**

```hcl
# modules/service/versions.tf
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker.target]
    }
  }
}
```

Mỗi resource trong module phải `provider = docker.target`.

**Provider alias ở root:**

```hcl
# starter/versions.tf
provider "docker" {}                          # default — cho module network
provider "docker" { alias = "east" }
provider "docker" { alias = "west" }
```

**Filter services theo region:**

```hcl
locals {
  services_east = { for k, v in local.services : k => v if v.region == "east" }
  services_west = { for k, v in local.services : k => v if v.region == "west" }
}

module "service_east" {
  source   = "./modules/service"
  for_each = local.services_east
  providers = { docker.target = docker.east }
  # ...
}
```

**Port offset trong module:**

```hcl
resource "docker_container" "this" {
  provider = docker.target
  for_each = toset([for i in range(var.replicas) : tostring(i)])

  name = "tflab-06-${var.name}-${each.key}"
  ports {
    internal = 80
    external = var.external_port + tonumber(each.key)
  }
  # ...
}
```

**Output forwarding khi module có for_each:**

```hcl
output "services_east" {
  value = { for k, m in module.service_east : k => m.urls }
}
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**`modules/service/main.tf`** — phần xương sống:

```hcl
locals {
  replica_keys = toset([for i in range(var.replicas) : tostring(i)])
  effective_labels = merge(
    { managed_by = "terraform", service = var.name },
    var.labels,
  )
}

resource "docker_image" "this" {
  provider     = docker.target
  name         = var.image
  keep_locally = true
}

resource "docker_container" "this" {
  provider = docker.target
  for_each = local.replica_keys

  name  = "tflab-06-${var.name}-${each.key}"
  image = docker_image.this.image_id

  networks_advanced {
    name    = var.network_name
    aliases = [var.name]
  }

  ports {
    internal = 80
    external = var.external_port + tonumber(each.key)
  }

  dynamic "healthcheck" {
    for_each = var.healthcheck.enabled ? [1] : []
    content {
      test     = ["CMD", "wget", "--spider", "-q", "http://localhost/"]
      interval = var.healthcheck.interval
      timeout  = "3s"
      retries  = 3
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

**Root `main.tf`** — phần xương sống:

```hcl
locals {
  services = {
    web    = { region = "east", image = "nginx:1.27-alpine", external_port = 8100, replicas = 2 }
    api    = { region = "west", image = "nginx:1.27-alpine", external_port = 8102, replicas = 1 }
    worker = { region = "east", image = "nginx:1.27-alpine", external_port = 8103, replicas = 1 }
  }
  services_east = { for k, v in local.services : k => v if v.region == "east" }
  services_west = { for k, v in local.services : k => v if v.region == "west" }
}

module "network" {
  source = "./modules/network"
  name   = "tflab-06-net"
  labels = { env = "dev" }
}

module "service_east" {
  source   = "./modules/service"
  for_each = local.services_east

  providers = { docker.target = docker.east }

  name          = each.key
  image         = each.value.image
  external_port = each.value.external_port
  network_name  = module.network.name
  replicas      = each.value.replicas
  labels        = { region = "east", role = each.key }
}

module "service_west" {
  source   = "./modules/service"
  for_each = local.services_west

  providers = { docker.target = docker.west }

  name          = each.key
  image         = each.value.image
  external_port = each.value.external_port
  network_name  = module.network.name
  replicas      = each.value.replicas
  labels        = { region = "west", role = each.key }
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):**

> Tôi đổi `worker.region` từ `"east"` thành `"west"`. Terraform sẽ làm gì?

Sẽ **destroy** `module.service_east["worker"]` và **create** `module.service_west["worker"]` —
container bị recreate, IP mới, downtime. Vì state address khác hoàn toàn. Trong production phải
dùng `moved { from = module.service_east["worker"] to = module.service_west["worker"] }` để
Terraform "đổi tên" thay vì destroy/create.

> Vì sao chia 2 module call thay vì 1 module call dùng `for_each` toàn bộ services?

Vì `providers = {}` của 1 module call là **static**, không thể `docker.target = docker[each.value.region]`.
Terraform yêu cầu mapping providers biết được lúc graph build. Đây là pattern documented — KHÔNG
phải limit chưa fix.

> Nếu thêm 1 region thứ 3 (`central`), workflow refactor như nào?

(1) Thêm `provider "docker" { alias = "central" }` ở root. (2) Thêm
`locals.services_central = { for k, v in local.services : k => v if v.region == "central" }`.
(3) Thêm 1 `module "service_central" { ... providers = { docker.target = docker.central } ... }`.
3 thay đổi cơ học. Không sửa module.

</details>
