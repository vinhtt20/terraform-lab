# Module `network`

Tạo 1 Docker bridge network với labels chuẩn. Module này region-agnostic —
KHÔNG nhận provider alias.

## Inputs

| Tên | Kiểu | Default | Mô tả |
|-----|------|---------|-------|
| `name` | `string` | — | Tên network (DNS-safe, regex `^[a-z0-9][a-z0-9_-]*$`). |
| `labels` | `map(string)` | `{}` | Labels bổ sung. Module tự thêm `managed_by=terraform` và `component=network`. |

## Outputs

| Tên | Mô tả |
|-----|-------|
| `id` | Network ID. |
| `name` | Network name (để các module khác attach container vào). |

## Ví dụ

```hcl
module "network" {
  source = "./modules/network"
  name   = "tflab-06-net"
  labels = { env = "dev" }
}
```
