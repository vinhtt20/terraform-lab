# Hints — Lab 08

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `import {}` block là cú pháp **declarative** thay cho lệnh `terraform import`.
  Mỗi block có 3 trường: `to` (Terraform address), `id` (live ID), optional
  `for_each` (TF ≥ 1.7).
- `-generate-config-out=FILE` chỉ chạy ĐƯỢC khi đã có `import {}` block trong
  config. Terraform đọc live attribute của resource → sinh khung HCL.
- Docker `volume` & `network` có thể import bằng NAME — provider tự match.
  `container` thì BẮT BUỘC full container ID (dynamic). Bạn cần cách nào đó
  để có ID ở plan time.
- Nghĩ thử: `data "external"` chạy 1 script (vd `bash -c`) ra JSON, Terraform
  đọc thành map dùng trong `id = data.external.X.result["app1"]`.
- `generated.tf` là draft — **đừng commit thẳng**. Refactor → for_each + locals
  cho gọn rồi mới apply.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Workflow chuẩn:**

```
1. setup.sh                               (legacy stack)
2. cd starter && terraform init
3. Viết imports.tf: data.external + 3 import block
4. terraform plan -generate-config-out=generated.tf
5. Đọc generated.tf — DRY-fy thành for_each, locals
6. Chuyển code đã refactor sang main.tf, update `to = ...` trong imports.tf
7. terraform plan      → "N to import"
8. terraform apply
9. terraform plan      → "No changes"
10. rm generated.tf  (+ optional rm imports.tf)
```

**Cấu trúc `data "external"` lấy container ID:**

```hcl
data "external" "container_ids" {
  program = ["bash", "-c", <<-EOT
    jq -n \
      --arg app1 "$(docker inspect --format '{{.Id}}' tflab-08-app1)" \
      --arg app2 "$(docker inspect --format '{{.Id}}' tflab-08-app2)" \
      --arg app3 "$(docker inspect --format '{{.Id}}' tflab-08-app3)" \
      '{app1: $app1, app2: $app2, app3: $app3}'
  EOT
  ]
}
```

Hợp đồng `external`: program in JSON; mọi value PHẢI là string. Đọc qua
`data.external.X.result.<key>`.

**Import block với for_each:**

```hcl
import {
  for_each = local.volumes
  to       = docker_volume.this[each.key]
  id       = "tflab-08-${each.key}"
}

import {
  for_each = local.apps
  to       = docker_container.app[each.key]
  id       = data.external.container_ids.result[each.key]
}
```

**Generated.tf "trước" vs main.tf "sau":**

```hcl
# generated.tf — Terraform sinh (rút gọn)
resource "docker_container" "tflab-08-app1" {
  name  = "tflab-08-app1"
  image = "sha256:abc..."
  ports { internal = 80, external = 8111 }
  volumes { volume_name = "tflab-08-data1", container_path = "/var/data" }
  restart = "unless-stopped"
  # ... 25 attribute default khác ...
}
# (tương tự cho app2, app3 — 3 resource block rời rạc)
```

```hcl
# main.tf — sau refactor
locals {
  apps = {
    app1 = { port = 8111, volume = "data1" }
    app2 = { port = 8112, volume = "data2" }
    app3 = { port = 8113, volume = null }
  }
}

resource "docker_container" "app" {
  for_each = local.apps
  name  = "tflab-08-${each.key}"
  image = docker_image.nginx.image_id
  # ...
}
```

Đừng quên đổi `to = docker_container.tflab-08-app1` → `to = docker_container.app["app1"]`
trong imports.tf.

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**Skeleton `imports.tf` (đầy đủ — chỉ ra ý tưởng):**

```hcl
data "external" "container_ids" {
  program = ["bash", "-c", <<-EOT
    jq -n \
      --arg app1 "$(docker inspect --format '{{.Id}}' tflab-08-app1)" \
      --arg app2 "$(docker inspect --format '{{.Id}}' tflab-08-app2)" \
      --arg app3 "$(docker inspect --format '{{.Id}}' tflab-08-app3)" \
      '{app1: $app1, app2: $app2, app3: $app3}'
  EOT
  ]
}

import {
  to = docker_network.main
  id = "tflab-08-net"
}

import {
  for_each = local.volumes
  to       = docker_volume.this[each.key]
  id       = "tflab-08-${each.key}"
}

import {
  for_each = local.apps
  to       = docker_container.app[each.key]
  id       = data.external.container_ids.result[each.key]
}
```

**Skeleton `main.tf` (phần xương sống):**

```hcl
locals {
  apps = {
    app1 = { port = 8111, volume = "data1" }
    app2 = { port = 8112, volume = "data2" }
    app3 = { port = 8113, volume = null }
  }
  volumes = toset(["data1", "data2"])
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_network" "main" {
  name   = "tflab-08-net"
  driver = "bridge"
}

resource "docker_volume" "this" {
  for_each = local.volumes
  name     = "tflab-08-${each.key}"
}

resource "docker_container" "app" {
  for_each = local.apps

  name  = "tflab-08-${each.key}"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.main.name
  }

  ports {
    internal = 80
    external = each.value.port
  }

  dynamic "volumes" {
    for_each = each.value.volume == null ? [] : [each.value.volume]
    content {
      volume_name    = docker_volume.this[volumes.value].name
      container_path = "/var/data"
    }
  }

  restart      = "unless-stopped"
  must_run     = true
  network_mode = "default"
  log_driver   = "json-file"

  # log_opts host-default → ignore:
  lifecycle {
    ignore_changes = [log_opts]
  }
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):**

> Vì sao tôi cần `data "external"` cho container nhưng không cần cho volume/network?

Vì kreuzwerker/docker provider chấp nhận `name` làm import ID cho volume/network
(provider tự match theo name field). Container BẮT BUỘC full SHA ID. Đây là
giới hạn provider, không phải của import block.

> Nếu tôi đổi `each.value.volume` của app3 từ `null` sang `"data3"` (tạo volume mới),
> điều gì xảy ra?

Cần (1) thêm `data3` vào `local.volumes`, (2) container app3 sẽ được modify
(không recreate vì dynamic block thay đổi nội dung). Plan: 1 to add (volume),
1 to change (container). Không drift legacy data vì data1/data2 không bị đụng.

> Tôi `terraform apply` mà chưa kịp refactor generated.tf — chuyện gì xảy ra?

Nếu địa chỉ trong generated.tf trùng với `to = ...` trong imports.tf → import
THÀNH CÔNG nhưng state sẽ có resource với tên xấu (`docker_container.tflab-08-app1`
thay vì `docker_container.app["app1"]`). Refactor sau apply phải dùng `moved {}`
block — phức tạp hơn. **Bài học:** refactor TRƯỚC apply.

> Tôi muốn import thêm 5 container nữa tuần sau. Workflow?

(1) `setup_more.sh` tạo container thêm; (2) thêm key vào `local.apps`; (3) thêm
key vào `data.external.container_ids` (cập nhật jq command); (4) import block
đã dùng `for_each = local.apps` → tự "biết" có thêm key mới. Plan sẽ báo
"5 to import". Đây là sức mạnh của for_each trên import block.

</details>
