# PREREQUISITES — chuẩn bị môi trường

## Bắt buộc

| Tool | Version tối thiểu | Cài đặt |
|------|-------------------|---------|
| **Terraform** | 1.9.0 (1.10+ cho lab 12) | `brew install terraform` hoặc `tfenv install 1.14.9` |
| **Docker** | 24.0+ (đã test 29.x) | Docker Desktop hoặc Colima |
| **bash** | 4.0+ | macOS mặc định 3.2 — `brew install bash` để có 5.x |
| **jq** | 1.6+ | `brew install jq` |
| **git** | bất kỳ | `brew install git` |

## Tuỳ chọn (chỉ cần cho lab cụ thể)

| Tool | Lab cần | Cài đặt |
|------|---------|---------|
| **conftest** | Lab 13 (Policy as Code) | `brew install conftest` |
| **OpenTofu** | (so sánh tham khảo) | `brew install opentofu` |
| **terraform-docs** | (gen module docs) | `brew install terraform-docs` |

## Xác minh nhanh

```bash
bash scripts/check-env.sh
```

Kết quả mong đợi:

```
✅ terraform >= 1.9.0   (v1.14.9)
✅ docker >= 24.0.0     (29.4.0)
✅ jq present           (1.7.1)
✅ bash >= 4.0          (...)
⚠  conftest missing    (chỉ cần cho lab 13)
```

## Khởi động Docker

```bash
# macOS Docker Desktop: mở app, đợi đèn xanh.
# Hoặc Colima:
colima start

docker ps   # phải chạy được không lỗi permission
```

## Cấu hình Terraform cho lab này

```bash
# Khuyến nghị bật plugin cache để init nhanh hơn (init lại nhiều lần)
mkdir -p ~/.terraform.d/plugin-cache
cat >> ~/.terraformrc <<'EOF'
plugin_cache_dir   = "$HOME/.terraform.d/plugin-cache"
disable_checkpoint = true
EOF
```

## Gỡ rối thường gặp

**`Error: failed to dial gRPC: cannot resolve docker host`**
Docker chưa chạy. Mở Docker Desktop hoặc `colima start`.

**`Error: Unsupported Terraform Core version`**
Lab yêu cầu Terraform >= 1.9 (lab 12 >= 1.10). Nâng cấp: `tfenv install 1.14.9 && tfenv use 1.14.9`.

**`Error: Failed to query available provider packages`**
Mạng chặn registry HashiCorp. Thử: `export TF_REGISTRY_DISCOVERY_RETRY=10` hoặc dùng mirror.

**Port đã bị chiếm**
Các lab dùng cổng 8080–8099 cho HTTP và 5432–5439 cho Postgres. Đổi cổng qua biến nếu cần
(xem lab 02 trở đi).

**`.terraform` quá lớn**
Đã có trong `.gitignore`. Nếu lỡ commit: `git rm -r --cached lab-*/starter/.terraform`.
