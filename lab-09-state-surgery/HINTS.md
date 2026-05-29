# Hints — Lab 09

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- `moved {}` block (TF 1.1+) là declarative version của `terraform state mv`.
  3 ưu điểm: plannable, reviewable qua PR, idempotent (no-op nếu đã migrate).
- `removed {}` block (TF 1.7+) là declarative version của `terraform state rm`.
  Mặc định nó **destroy** resource — nếu bạn muốn giữ live (handover), phải
  thêm `lifecycle { destroy = false }`.
- Để `moved {}` thực sự là "thuần state migration" (zero downtime), attribute
  force-replacement của resource phải **không đổi**. Container `name` là một
  force-replacement attribute trong kreuzwerker/docker.
- Suy nghĩ: nếu container hiện có tên `tflab-09-web1`, và config mới đặt
  `name = "tflab-09-${each.key}"`, thì `each.key` phải bằng gì để name khớp?
- Khi xoá resource block khỏi config, đừng xoá luôn `moved {}` block — Terraform
  cần nó để biết "address cũ đã đi đâu".

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Workflow đúng:**

```
1. terraform apply         # bootstrap legacy state (3 separate resources)
2. terraform state list    # confirm web1, web2, web3 trong state
3. Sửa main.tf:
   - Thêm locals.apps = { web1 = {...}, web2 = {...} }   # KEY = "web1"/"web2"!
   - Thêm resource "docker_container" "web" với for_each = local.apps
   - XOÁ 3 resource cũ (web1, web2, web3)
   - Thêm moved blocks: web1 → web["web1"], web2 → web["web2"]
   - Thêm removed block cho web3 (destroy = false)
4. Sửa outputs.tf: gộp thành output urls (map)
5. terraform plan
   → Đầu ra MONG ĐỢI: "Plan: 0 to add, 0 to change, 0 to destroy."
   → Nếu thấy "to add" hoặc "to destroy" KHÁC 0 cho container → name bị đổi!
6. terraform apply  # state migration; infra Docker không touch
7. terraform plan   # phải báo "No changes"
```

**`moved {}` syntax:**

```hcl
moved {
  from = docker_container.web1            # address cũ
  to   = docker_container.web["web1"]     # address mới
}
```

**`removed {}` syntax (preserve live):**

```hcl
removed {
  from = docker_container.web3

  lifecycle {
    destroy = false   # KEY POINT — không có dòng này, web3 bị destroy
  }
}
```

**Tự kiểm trước khi apply:**

- `terraform plan` không được có dòng *"will be destroyed"* cho `web1` hay
  `web2`. Nếu có → `name` đang đổi → sửa key trong `locals.apps`.
- Plan PHẢI có 2 dòng *"has moved to"* và 1 dòng *"will no longer be managed
  by Terraform"* cho web3.

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**Skeleton `main.tf` sau refactor:**

```hcl
locals {
  apps = {
    web1 = { port = 8191 }    # KEY phải là "web1" để name = "tflab-09-web1"
    web2 = { port = 8192 }    # KEY phải là "web2"
  }
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  for_each = local.apps

  name  = "tflab-09-${each.key}"   # → "tflab-09-web1", "tflab-09-web2"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = each.value.port
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}

moved {
  from = docker_container.web1
  to   = docker_container.web["web1"]
}

moved {
  from = docker_container.web2
  to   = docker_container.web["web2"]
}

removed {
  from = docker_container.web3

  lifecycle {
    destroy = false
  }
}
```

**Skeleton `outputs.tf` sau refactor:**

```hcl
output "urls" {
  description = "Public URLs of managed containers."
  value = {
    for k, c in docker_container.web : k => "http://localhost:${c.ports[0].external}"
  }
}
```

**Câu hỏi tự kiểm (chuyên gia sẽ hỏi):**

> Nếu tôi đặt key trong `locals.apps` là `"app1"` thay vì `"web1"`, plan sẽ ra sao?

`name` sẽ thành `tflab-09-app1`, khác với `tflab-09-web1` hiện có. `name`
là force-replacement attribute → Terraform sẽ DESTROY `docker_container.web1`
và CREATE `docker_container.web["app1"]`. Plan: 2 to add, 2 to destroy.
`moved {}` rename address nhưng KHÔNG cứu được khi attribute thay đổi.

> Tôi quên `destroy = false`. Apply có gì lạ?

Web3 sẽ bị destroy thật. Plan sẽ thấy `# docker_container.web3 will be
destroyed`. Team B nhận được container đã chết → bị mắng. Phải `terraform
import` lại nếu container đã restart.

> Khi nào tôi xoá được các `moved {}` block?

Sau khi **mọi** state file trong tổ chức đã apply qua block ít nhất 1 lần.
Trong lab này chỉ có 1 state → có thể xoá ngay sau apply. Production: chờ
1–2 release cycle. Quy tắc thực dụng: nếu git blame block > 6 tháng và không
ai báo lỗi → có thể xoá.

> Tôi muốn dùng `terraform state mv` CLI thay vì block. OK không?

OK về mặt kỹ thuật, lab này verify cả 2 cách (state list cuối phải đúng).
**Nhưng** verify.sh script bắt buộc tìm `moved {}` block trong main.tf →
nếu chỉ dùng CLI, FAIL. Đây là enforcement có chủ đích: production team
phải audit qua PR.

> Tôi đổi sang `for_each = toset([...])` thay vì map. Có sao không?

`each.key == each.value` cho toset. Vẫn OK miễn key string ăn khớp tên cũ.
Nhược điểm: thông tin port phải lookup ngoài (vd: map riêng). Map giàu hơn.

</details>
