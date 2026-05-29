# Lab 10 — Backends, Workspaces, Drift

> **Cấp độ:** Nâng cao
> **Thời lượng dự kiến:** ~75 phút
> **Yêu cầu trước:** Lab 00–09. Hiểu state file & life cycle. Lab 09 (`moved`/`removed`) bổ trợ.

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Khai báo explicit local backend** — hiểu vì sao "default = local" không
   đồng nghĩa với "khỏi viết". Khai báo giúp PR review thấy được backend
   đang dùng + chuẩn bị migrate sang remote backend sau này.
2. **Dùng workspaces** để deploy **một** config sang **nhiều** môi trường
   (dev, prod) với state hoàn toàn tách biệt — không cần copy folder.
3. **Phân biệt drift loại "infra-side"** (ai đó sửa thủ công ngoài Terraform)
   với **drift loại "config-side"** (code thay đổi nhưng chưa apply).
4. **Vận hành `-refresh-only`** để đồng bộ state với reality mà không
   modify infra; hiểu giới hạn (chỉ sync state, không "fix" drift).
5. **Hiểu khi nào workspace KHÔNG phải lựa chọn đúng** (vd: prod khác dev
   về kiến trúc, không chỉ kích thước).

## 🌐 Bối cảnh

Trưởng nhóm vừa giao một config nginx và bảo: *"Cần deploy ra dev và prod.
Prod 2 replica, dev 1 replica. Đừng fork code thành 2 thư mục."*

Tuần sau, lúc on-call, bạn nhận page: container prod-1 bị mất tích. Bạn
chạy `terraform plan` ở prod workspace — Terraform báo "will be replaced".
Vì sao Terraform biết? Vì state ghi nhận container nào "thuộc về" Terraform,
và **refresh** so sánh state với reality khi chạy plan.

Đây là use case kinh điển của **workspaces** + **drift detection** + đôi
khi **`-refresh-only`**.

## 📋 Yêu cầu cụ thể

### File `starter/versions.tf`

- [ ] Khai báo `backend "local" {}` explicit trong block `terraform {}`.

### File `starter/main.tf`

- [ ] Đã có `locals.cfg = lookup(var.workspace_config, terraform.workspace, ...)`.
- [ ] Tạo `resource "docker_container" "app"`:
  - `count = local.cfg.replicas`
  - `name = "tflab-10-${terraform.workspace}-${count.index + 1}"`
  - port external = `local.cfg.port + count.index`
  - Có `labels { label = "tflab.workspace"; value = terraform.workspace }`
  - `restart = "unless-stopped"`, `must_run = true`
  - `lifecycle { ignore_changes = [log_opts] }`

### File `starter/outputs.tf`

- [ ] Output `workspace_name` (đã có sẵn).
- [ ] Output `urls` (list, ordered by count.index).
- [ ] Output `container_ids` (list, ordered by count.index).

### Workspaces & deploy

- [ ] `terraform init`
- [ ] `terraform workspace new dev && terraform apply` → 1 container :8201.
- [ ] `terraform workspace new prod && terraform apply` → 2 container :8202, :8203.
- [ ] `terraform workspace list` hiện `default`, `dev`, `prod`.

### Bài tập drift (thực hành thủ công, không bắt buộc trong verify)

- [ ] **Drift A:** `docker stop tflab-10-dev-1` → `terraform plan` (dev) báo
      "will be replaced". Apply để remediate.
- [ ] **Drift B:** thêm label thủ công:
      `docker container update --label-add manual=true tflab-10-dev-1`
      → `terraform plan -refresh-only` để xem drift; `terraform apply
      -refresh-only` để cập nhật state. Hiểu kết quả.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể:

- `terraform fmt -check -recursive` (starter) sạch.
- `terraform validate` pass.
- `versions.tf` có `backend "local" {}`.
- `main.tf` tham chiếu `terraform.workspace`.
- Workspaces `dev` và `prod` đã được tạo.
- State files trong `terraform.tfstate.d/{dev,prod}/`.
- Container `tflab-10-{dev-1, prod-1, prod-2}` đang chạy, có đúng label.
- Plan idempotent ở cả 2 workspace.
- Output `workspace_name`, `urls`, `container_ids` đúng giá trị.

## 🧭 Hướng dẫn làm

```bash
cd starter

# 1) Hoàn thiện code: thêm backend "local" {}, container resource, outputs.
$EDITOR versions.tf main.tf outputs.tf

# 2) Init (đọc backend mới)
terraform init

# 3) Workspace dev
terraform workspace new dev
terraform workspace show       # "dev"
terraform apply
docker ps --filter name=tflab-10-dev  # tflab-10-dev-1 on :8201

# 4) Workspace prod
terraform workspace new prod
terraform apply
docker ps --filter name=tflab-10-prod # tflab-10-prod-1 (:8202), tflab-10-prod-2 (:8203)

# 5) Kiểm tra state riêng biệt
ls terraform.tfstate.d/
# dev/  prod/

terraform workspace list
#   default
# * prod          # asterisk = workspace hiện tại
#   dev

# 6) Bài tập drift A
docker stop tflab-10-dev-1
terraform workspace select dev
terraform plan
# # docker_container.app[0] will be replaced ...
terraform apply

# 7) Bài tập drift B (refresh-only)
docker container update --label-add manual=true tflab-10-dev-1
terraform plan
# Plan: 0 to add, 1 to change, 0 to destroy.   ← Terraform muốn xoá label
terraform plan -refresh-only
# Note: Objects have changed outside of Terraform
terraform apply -refresh-only
# State đã sync; KHÔNG xoá label thủ công.
# Tuy nhiên `terraform plan` tiếp theo VẪN báo "1 to change" vì config
# (không có label "manual") khác state. Đây là điểm cốt lõi của
# refresh-only: chỉ sync state, không reconcile drift.

cd ..
bash verify.sh

# Dọn dẹp khi xong:
cd starter
terraform workspace select dev && terraform destroy
terraform workspace select prod && terraform destroy
terraform workspace select default
terraform workspace delete dev
terraform workspace delete prod
```

## 🧠 Đào sâu (expert)

### Vì sao khai báo `backend "local" {}` explicit?

Terraform mặc định dùng local backend nếu bạn không khai báo gì. Khai báo
explicit cho 3 mục đích:

1. **Audit trail trong PR.** Reviewer nhìn `versions.tf` biết ngay backend
   đang dùng. Tránh "ngầm hiểu" sai (vd: nghĩ là remote nhưng thật ra local).
2. **Chuẩn bị migrate.** Khi đổi sang `backend "s3"` hay `backend "remote"`,
   diff PR rõ ràng. Không khai báo trước → diff sẽ là "thêm 1 block" — khó
   review hơn "đổi attribute".
3. **`-backend-config` override.** Bạn có thể `terraform init -backend-config=path=...`
   để override state path khi cần (vd: CI tách path theo branch). Chỉ
   override được nếu có block khai báo.

### Workspaces — khi nào dùng, khi nào tránh

**Dùng khi:**
- Cùng 1 config, khác **kích thước** (replicas, instance size).
- Cùng 1 config, khác **tags/labels** môi trường.
- POC, demo, throwaway env.

**Tránh khi:**
- **Prod khác dev về architecture** (vd: prod có RDS, dev dùng SQLite).
  Workspace ép bạn nhồi `count = 0` everywhere → code khó đọc, dễ lỗi.
- **Cần audit phân biệt rõ** (compliance: ai apply prod, khi nào). Trong
  workspace, lỗi gõ `select dev` thay `select prod` → áp dụng nhầm môi
  trường. Nhiều team thay bằng **folder per environment** + remote backend
  per environment.
- **State backup khác nhau.** Workspace dùng cùng backend → backup chung.
  Prod thường cần backup riêng, retention dài hơn.

**Quy tắc thực dụng:** workspace cho "scaling" (cùng shape, khác size).
Folder per env cho "shape" (architecture khác nhau). Lab 14 (capstone)
demo cả 2.

### Drift loại I vs loại II

| Loại | Triệu chứng | Giải pháp |
|---|---|---|
| **I — Infra-side** (ai đó sửa thủ công) | `plan` báo diff dù bạn không sửa code | (a) `apply` để Terraform "thắng", hoặc (b) `apply -refresh-only` + sửa code để chấp nhận drift, hoặc (c) `import` nếu drift là resource mới |
| **II — Config-side** (code mới, chưa apply) | `plan` báo diff khớp với commit gần đây | `apply` |

Tip: dùng `git status` + `git log` để phân biệt nhanh. Code mới = loại II.
Code sạch nhưng plan có diff = loại I.

### `-refresh-only` — semantics chính xác

```bash
terraform apply -refresh-only
```

1. **Đọc reality** (call provider API cho mọi resource trong state).
2. **Update state file** để khớp reality.
3. **KHÔNG modify infra.**

Nếu reality có label/tag thêm bởi tay → state ghi nhận label đó. Nhưng
**config không có** → `terraform plan` lần sau vẫn báo "remove label".
Tức là `-refresh-only` không "fix" drift, chỉ **document** nó.

**Khi nào `-refresh-only` hữu ích:**

- **Drift cần điều tra trước khi quyết định.** Trước khi `apply` (overwrite drift)
  hay `import` (accept drift), `-refresh-only` cho bạn state file "đúng" để
  diff với config.
- **Sau provider upgrade.** Provider mới có thể đọc thêm field → state cần
  refresh để pick up; chưa sẵn sàng `apply` các diff khác.
- **Audit incident.** Snapshot reality vào state để forensics.

`terraform refresh` (subcommand cũ) đã deprecated từ TF 0.15 — dùng
`apply -refresh-only` thay thế. Có acknowledgement prompt, an toàn hơn.

### State file: cấu trúc per-workspace

Local backend tự động chia state theo workspace:

```
starter/
├── terraform.tfstate          # workspace "default" (KHÔNG tạo nếu default rỗng)
└── terraform.tfstate.d/
    ├── dev/
    │   └── terraform.tfstate
    └── prod/
        └── terraform.tfstate
```

Remote backend (S3, HTTP, Terraform Cloud) cũng tách per workspace nhưng
qua **prefix/key**. Chuyển backend → workspace bảo toàn (nếu backend mới
hỗ trợ workspaces).

### State locking — local backend có không?

**Có** (file-based lock). Khi `apply` đang chạy, Terraform tạo
`.terraform.tfstate.lock.info` cạnh state file. Apply song song khác sẽ
bị block với lỗi `Error acquiring the state lock`.

**Hạn chế:** lock chỉ "hứa" trong filesystem cùng máy. Nếu state ở NFS chia
sẻ nhiều máy → có race. Sản xuất → remote backend với DynamoDB / Postgres
locking.

### Backup state

Mỗi lần `apply` Terraform tự backup state sang `*.tfstate.backup`. Lưu ý:

- Chỉ giữ **1** version cũ.
- Không có "version history" cho local backend.
- Sản xuất → enable `versioning` ở S3 hoặc dùng remote backend có history.

Khôi phục:
```bash
cp terraform.tfstate.d/prod/terraform.tfstate.backup \
   terraform.tfstate.d/prod/terraform.tfstate
```

### Cạm bẫy thường gặp

1. **Quên `workspace select` trước `apply`.** Apply vào nhầm workspace →
   tạo container ở env khác → confusion. Tip: prompt shell hiển thị
   `terraform.workspace` (vd: terraform-prompt).
2. **Đổi `workspace_config` cho prod mà không apply prod ngay.** Diff treo
   trong git, ai khác apply sẽ surprised. Apply ngay sau commit.
3. **`terraform.workspace == "default"` mà default không có trong map.**
   `lookup(map, key)` không có default → error. Dùng `lookup(map, key, fallback)`.
4. **Workspace có asterisk `*` trong `terraform workspace list`.**
   Đó là indicator workspace hiện tại — không phải tên thật. Bash script
   phải `tr -d '*'` trước khi so sánh.
5. **`terraform workspace delete` cho workspace có resource.** Bị chặn —
   phải destroy trước.

### Docs tham khảo

- Backends overview: <https://developer.hashicorp.com/terraform/language/backend>
- Local backend: <https://developer.hashicorp.com/terraform/language/backend/local>
- Workspaces: <https://developer.hashicorp.com/terraform/language/state/workspaces>
- `-refresh-only`: <https://developer.hashicorp.com/terraform/cli/commands/apply#refresh-only>
- State locking: <https://developer.hashicorp.com/terraform/language/state/locking>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
