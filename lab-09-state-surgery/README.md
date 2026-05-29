# Lab 09 — State Surgery (`moved {}` + `removed {}`)

> **Cấp độ:** Nâng cao
> **Thời lượng dự kiến:** ~90 phút
> **Yêu cầu trước:** Lab 00–08 (đặc biệt Lab 05–06 về modules và Lab 07–08 về import).

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Refactor address Terraform** từ resource rời rạc sang resource `for_each`
   **mà không destroy/recreate** infrastructure thật — đây là "zero-downtime
   state surgery".
2. **Dùng `moved {}` block** thay vì `terraform state mv` CLI: declarative,
   plannable, review-able qua PR, idempotent, có thể `git revert` để rollback.
3. **Dùng `removed {}` block với `lifecycle { destroy = false }`** để xoá
   resource khỏi state mà **giữ object live** — use case kinh điển khi
   handover quyền quản lý cho team khác.
4. **Hiểu khi nào `moved {}` thực sự move vs. force replace.** Nếu attribute
   force-replacement thay đổi (như `name` của container), Terraform vẫn destroy
   và recreate — `moved {}` không "tha".
5. **So sánh** declarative blocks vs. CLI commands (`state mv/rm/replace-provider`)
   — biết khi nào dùng cái nào.

## 🌐 Bối cảnh

Module monolith `web-stack` của bạn có 3 container nginx được declare rời rạc:

```hcl
resource "docker_container" "web1" { ... }
resource "docker_container" "web2" { ... }
resource "docker_container" "web3" { ... }
```

Hai tin xấu vừa ập đến cùng lúc:

1. **Anh kiến trúc trưởng** vừa review code: *"Vì sao đang dùng `for_each` ở
   các module khác mà 3 web container này lại copy-paste? Refactor đi."*
2. **Team Operations B** vừa email: *"Bọn em sẽ quản web3 từ thứ Hai. Đừng
   destroy nó — chỉ stop tracking trong Terraform của bạn là được."*

Yêu cầu chung: **không có downtime**, **không destroy/recreate container**,
**toàn bộ thay đổi visible trong PR** (operations cần audit trail). Đây là
use case **kinh điển** của `moved {}` + `removed {}`.

## 📋 Yêu cầu cụ thể

### Bước 0 — Bootstrap (làm 1 lần)

- [ ] `cd starter && terraform init`
- [ ] `terraform apply` để tạo state với 4 entries
      (`docker_image.nginx`, `docker_container.web1/2/3`).
- [ ] Confirm 3 container live: `docker ps --filter name=tflab-09`

### Refactor `starter/main.tf`

- [ ] Thêm `locals.apps = { web1 = {...}, web2 = {...} }` — **key phải là
      `"web1"`/`"web2"`** để `name = "tflab-09-${each.key}"` reproduce chính
      xác tên container hiện có.
- [ ] Tạo `resource "docker_container" "web"` với `for_each = local.apps`.
- [ ] XOÁ 3 `resource "docker_container" "web1"/"web2"/"web3"` cũ.
- [ ] Thêm 2 `moved {}` block:
  - `web1 → web["web1"]`
  - `web2 → web["web2"]`
- [ ] Thêm 1 `removed {}` block cho `web3` với `lifecycle { destroy = false }`.

### Refactor `starter/outputs.tf`

- [ ] Bỏ 3 output rời rạc.
- [ ] Thêm 1 output `urls` dạng map `{ web1 = "...", web2 = "..." }`.

### Trạng thái cuối

- [ ] `terraform state list` chỉ có 3 entries:
      `docker_image.nginx`, `docker_container.web["web1"]`,
      `docker_container.web["web2"]`.
- [ ] **Cả 3 container Docker** (`tflab-09-web1/2/3`) vẫn đang chạy —
      `web3` sống nhờ `destroy = false`.
- [ ] `terraform plan -detailed-exitcode` exit 0 (idempotent).

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể:

- `terraform fmt -check -recursive` (starter) sạch.
- `terraform validate` (starter) pass.
- `main.tf` có `moved {}` blocks (declarative migration).
- `main.tf` có `removed {}` block với `destroy = false`.
- State có 3 expected addresses, không còn legacy `web1/web2/web3`.
- 3 container `tflab-09-web1/2/3` vẫn đang chạy.
- Output `urls.web1`, `urls.web2` đúng giá trị.
- `terraform plan` lần 2 → 0 changes.

## 🧭 Hướng dẫn làm

```bash
# 1) Bootstrap legacy state
cd starter
terraform init
terraform apply
terraform state list   # 4 entries: image + web1 + web2 + web3

# 2) Mở main.tf, theo TODO STEP 2:
#    - Thêm locals.apps
#    - Thêm resource docker_container.web (for_each)
#    - Xoá 3 resource cũ
#    - Thêm 2 moved {} + 1 removed {}
$EDITOR main.tf outputs.tf

# 3) Plan — kiểm tra trước khi apply
terraform plan
# Đầu ra mong đợi:
#   # docker_container.web1 has moved to docker_container.web["web1"]
#   # docker_container.web2 has moved to docker_container.web["web2"]
#
#   Warning: Some objects will no longer be managed by Terraform
#    - docker_container.web3
#
#   Plan: 0 to add, 0 to change, 0 to destroy.

# 4) Apply — state được update, infra Docker KHÔNG đụng vào
terraform apply

# 5) Kiểm tra
terraform state list                                  # 3 entries (web3 đã rời state)
docker ps --filter name=tflab-09 --format '{{.Names}}' # web1, web2, web3 ĐỀU sống

# 6) Idempotency
terraform plan       # No changes

cd ..
bash verify.sh

# Dọn dẹp khi xong:
cd starter && terraform destroy   # destroy web1, web2 (Terraform-managed)
docker rm -f tflab-09-web3        # destroy web3 thủ công (đã rời state)
```

## 🧠 Đào sâu (expert)

### `moved {}` — cơ chế thực sự

```hcl
moved {
  from = docker_container.web1
  to   = docker_container.web["web1"]
}
```

**Khi `terraform plan` chạy:**
1. Terraform thấy `from` còn trong state nhưng resource block đã biến mất.
2. Trước khi báo "X will be destroyed", Terraform check `moved {}`: address này
   được migrate sang `to`.
3. Nếu `to` tồn tại trong config (tức resource block với address `to`):
   → **rename trong state**, KHÔNG destroy/create.
4. Nếu **attribute** force-replacement vẫn khác → vẫn replace (đây là cạm bẫy
   lớn nhất; xem mục "Cạm bẫy" bên dưới).

**Khi nào xoá `moved {}` block:** sau khi mọi state file trong tổ chức đã
được apply qua block ít nhất một lần (thường 1–2 release cycle). Trước đó
xoá sớm → ai chưa rebase chạy `terraform plan` sẽ thấy "destroy + create"
thay vì "moved" → tai nạn.

### `removed {}` — cơ chế thực sự

```hcl
removed {
  from = docker_container.web3
  lifecycle {
    destroy = false   # MANDATORY nếu muốn giữ object live
  }
}
```

- `destroy = false` → equivalent với `terraform state rm` (chỉ quên state).
- `destroy = true` (default) → equivalent với xoá resource block (destroy +
  state remove). **Đừng nhầm:** mặc định của `removed {}` IS destroy=true.
- `removed {}` đòi resource block ĐÃ bị xoá khỏi config. Nếu cả 2 cùng tồn
  tại → lỗi *"Removed block defines a removed resource which is still in
  configuration"*.

### Declarative blocks vs. CLI

| Tác vụ | CLI | Declarative |
|---|---|---|
| Rename address | `terraform state mv X Y` | `moved { from=X to=Y }` |
| Quên resource | `terraform state rm X` | `removed { from=X; lifecycle { destroy=false } }` |
| Destroy + quên | (xoá block) + `apply` | `removed { from=X }` (destroy=true mặc định) |
| Đổi source provider | `terraform state replace-provider OLD NEW` | (chưa có declarative; vẫn dùng CLI) |

| Tiêu chí | CLI | Block |
|---|---|---|
| Plannable | KHÔNG | CÓ |
| Reviewable trong PR | KHÔNG | CÓ |
| Idempotent | Lần 2 báo lỗi | Lần 2 no-op |
| Lưu lại trong history | Chỉ shell history | Git history |
| Rollback | Phải nhớ command nghịch đảo | `git revert` |

→ Production: **luôn dùng block trước**. CLI để fix nóng (incident response
giữa đêm, không kịp mở editor + raise PR).

### `terraform state replace-provider` — khi nào dùng

Use case: provider source thay đổi (vd: `terraform-providers/aws` →
`hashicorp/aws` thời migration ~2020; hoặc fork provider từ source A sang
fork B). Khi `terraform init` báo *"provider X is not the same as provider Y
in state"*, chạy:

```bash
terraform state replace-provider \
  registry.terraform.io/-/aws \
  registry.terraform.io/hashicorp/aws
```

KHÔNG có declarative equivalent (TF 1.14). Đây là một trong vài tác vụ
state CLI vẫn cần thiết. Lab này không bắt buộc thực hành (Docker provider
không có source change), nhưng nhớ tồn tại của nó.

### Vì sao `moved {}` vẫn destroy/recreate?

Cạm bẫy số 1 của lab này. Plan bạn KHÔNG muốn thấy:

```
Plan: 2 to add, 0 to change, 2 to destroy.
```

Nguyên nhân: attribute force-replacement (`name` của Docker container) thay
đổi giữa "trước" và "sau". `moved {}` rename address, nhưng Terraform vẫn
thấy config khác → diff → replace.

**Quy tắc:** chỉ `moved {}` thuần khi resource có **cùng** mọi attribute
force-replacement. Nếu cần đổi name luôn thì:
1. Apply `moved {}` riêng (chỉ rename address).
2. Sau đó apply đổi name trong release riêng (chấp nhận destroy/recreate
   có lịch).

### `state mv` còn dùng được không?

Có. Dùng khi:
- Refactor cấp module-to-module: `terraform state mv module.old.X module.new.Y`
  (`moved {}` cũng làm được, nhưng CLI nhanh hơn khi explore).
- Cross-state move: `terraform state mv -state=src.tfstate -state-out=dst.tfstate X X`
  — `moved {}` không hỗ trợ cross-state.
- Fix khẩn cấp khi state bị "lệch" do bug provider — declarative đòi `plan`
  trước, CLI không.

Sau khi CLI xong, **nhớ thêm `moved {}` block trong code** để đồng bộ với
teammate khác (họ không có hành động CLI của bạn trong shell history của họ).

### Cạm bẫy thường gặp

1. **Đổi name container/resource khi refactor.** `moved {}` không cứu —
   xem mục trên.
2. **Quên `destroy = false` trong `removed {}`.** Default IS destroy=true →
   web3 bị destroy. Đọc kỹ docs.
3. **Để resource block + `removed {}` cùng tồn tại.** Lỗi. Phải XOÁ resource
   block.
4. **`moved { from = X }` mà `X` không bao giờ có trong state** (vd: code
   mới viết, chưa từng apply). Terraform báo warning nhưng vẫn pass — chỉ
   noise. Có thể xoá block sau release đầu tiên.
5. **Xoá `moved {}` quá sớm.** Teammate chưa rebase chạy plan sẽ thấy
   "destroy + create". Giữ ít nhất 1 release cycle.
6. **Dùng `state mv` thay vì block trong PR có review.** Lịch sử ở shell,
   reviewer không thấy → audit fail. Reserve cho incident response.

### Bonus: dùng CLI để verify (đọc state mà không mutate)

```bash
terraform state list                           # liệt kê address
terraform state show 'docker_container.web["web1"]'   # chi tiết 1 resource
terraform state pull | jq '.resources[].type'  # mọi type trong state
```

3 lệnh trên hoàn toàn read-only, dùng debug an toàn.

### Docs tham khảo

- `moved {}` block: <https://developer.hashicorp.com/terraform/language/modules/develop/refactoring>
- `removed {}` block: <https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources>
- State CLI: <https://developer.hashicorp.com/terraform/cli/commands/state>
- `state mv`: <https://developer.hashicorp.com/terraform/cli/commands/state/mv>
- `state rm`: <https://developer.hashicorp.com/terraform/cli/commands/state/rm>
- `state replace-provider`: <https://developer.hashicorp.com/terraform/cli/commands/state/replace-provider>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
