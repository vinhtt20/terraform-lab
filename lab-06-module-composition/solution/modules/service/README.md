# Module `service`

Deploy 1 service nginx có 1..3 replicas, gắn vào 1 Docker network có sẵn, có
optional healthcheck. Module này nhận **provider alias** từ caller — cho phép
deploy vào nhiều "region" khác nhau.

## Provider contract

Module khai báo `configuration_aliases = [docker.target]`. Root **BẮT BUỘC**
phải truyền provider vào qua `providers = { docker.target = docker.<alias> }`:

```hcl
module "service_east" {
  source = "./modules/service"
  providers = {
    docker.target = docker.east
  }
  # ... inputs
}
```

## Inputs

| Tên | Kiểu | Default | Mô tả |
|-----|------|---------|-------|
| `name` | `string` | — | Tên service (DNS-safe). |
| `image` | `string` | — | Image kèm tag, KHÔNG `:latest`. |
| `external_port` | `number` | — | Cổng host base. Replica `i` listens trên `external_port + i`. |
| `network_name` | `string` | — | Tên Docker network để attach. Truyền `module.network.name` từ root. |
| `replicas` | `number` | `1` | Số replicas, `1..3`. |
| `labels` | `map(string)` | `{}` | Labels bổ sung. |
| `healthcheck` | `object({ enabled, interval })` | `{ enabled = true, interval = "10s" }` | HTTP healthcheck. |

## Outputs

| Tên | Mô tả |
|-----|-------|
| `container_names` | List tên các replica container. |
| `urls` | List URL host (1 URL / replica). |
| `image_id` | Image ID đã deploy. |
| `replicas` | Echo input replicas. |

## Ví dụ

```hcl
module "service_east" {
  source = "./modules/service"
  providers = {
    docker.target = docker.east
  }

  name          = "web"
  image         = "nginx:1.27-alpine"
  external_port = 8100
  network_name  = module.network.name
  replicas      = 2
}
```
