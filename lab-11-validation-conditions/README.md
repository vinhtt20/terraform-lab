# Lab 11 — Validation & Custom Conditions

> **Cấp độ:** Expert
> **Thời lượng dự kiến:** ~60 phút
> **Yêu cầu trước:** Lab 00–10. Đặc biệt Lab 02 (variables) và Lab 03 (expressions).

## 🎯 Mục tiêu học

Sau lab này bạn sẽ:

1. **Viết `validation {}` block** cho input variables — chặn giá trị sai
   NGAY TỪ KHI parse, trước cả `plan`. Đây là tuyến phòng thủ rẻ nhất.
2. **Viết `precondition {}`** trong `lifecycle` — chặn action khi điều kiện
   chưa thỏa (vd: port ngoài range, môi trường sai).
3. **Viết `postcondition {}`** trong `lifecycle` — đảm bảo resource sau khi
   tạo có thuộc tính đúng kỳ vọng (vd: image_id non-empty, port bound đúng).
4. **Viết top-level `check {}` block** — assert invariant chéo nhiều resource;
   FAIL → warning chứ không stop apply (chiến lược "fail-soft").
5. **Chọn đúng layer cho đúng failure mode** — không phải lúc nào cũng là
   `validation`.

## 🌐 Bối cảnh

Trong nhóm, mỗi engineer chạy `terraform apply` từ máy mình. Một bạn gõ
nhầm `base_port = 80` → apply lỗi giữa chừng, container nửa tạo, ports
chiếm rồi không nhả. Tổn thất: 30 phút mỗi lần. Sếp bảo: *"Không thể để
chuyện này lặp lại. Thêm rào chắn vào code."*

Lab này dạy bạn 3 lớp rào chắn. Mỗi lớp đắt/rẻ và chính xác khác nhau —
biết đặt rào chắn đúng tầng là kỹ năng cốt lõi của expert Terraform.

## 📋 Yêu cầu cụ thể

### File `starter/variables.tf`

- [ ] Thêm 3 `validation {}` block:
  - `name_prefix`: regex `^[a-z][a-z0-9-]{2,30}$`
  - `base_port`: trong `[8000, 9999]`
  - `replicas`: trong `[1, 5]`

### File `starter/main.tf`

- [ ] Thêm `postcondition` cho `docker_image.nginx`:
      `self.image_id != ""`.
- [ ] Thêm `precondition` cho `docker_container.app`:
      `(var.base_port + count.index) < 10000`.
- [ ] Thêm `postcondition` cho `docker_container.app`:
      `length(self.ports) > 0 && self.ports[0].external == (var.base_port + count.index)`.
- [ ] Thêm top-level `check "unique_ports" {}` block: tất cả container
      phải có external port duy nhất.

### Trạng thái cuối

- [ ] `terraform fmt -check` sạch, `terraform validate` pass.
- [ ] `terraform apply` thành công với default values → 2 container
      `tflab-11-1` (:8221), `tflab-11-2` (:8222).
- [ ] `terraform plan -var "base_port=80"` BỊ CHẶN bởi validation.
- [ ] Idempotent: plan lần 2 → 0 changes.

## ✅ Tiêu chí pass

`bash verify.sh` in `PASS` và exit 0. Cụ thể:

- fmt, validate pass.
- `variables.tf` có >= 3 `validation` block.
- `main.tf` có precondition, postcondition, và check {} blocks.
- State có 3 entries; 2 container đang chạy với port đúng.
- Output `names`, `urls` đúng.
- Plan idempotent.
- Validation chặn `-var "base_port=80"` thành công.

## 🧭 Hướng dẫn làm

```bash
cd starter

# 1) Thêm 3 validation block vào variables.tf
$EDITOR variables.tf

# 2) Thêm pre/postcondition + check block vào main.tf
$EDITOR main.tf

# 3) Init + apply
terraform init
terraform apply

# 4) Thử negative test (validation phải chặn)
terraform plan -var "base_port=80"
# → "Error: Invalid value for variable: base_port must be in [8000, 9999]..."

terraform plan -var "name_prefix=Tflab-11"
# → "Error: Invalid value for variable: name_prefix must start with lowercase..."

terraform plan -var "replicas=10"
# → "Error: Invalid value for variable: replicas must be in [1, 5]..."

# 5) Verify
cd ..
bash verify.sh

# Dọn dẹp:
cd starter && terraform destroy
```

## 🧠 Đào sâu (expert)

### 3 lớp rào chắn — chọn đúng tầng

| Mechanism | Khi nào chạy | Reference được gì | Failure |
|---|---|---|---|
| `variable validation {}` | Parse time (trước plan) | Chỉ `var.<self>` | Hard fail |
| `lifecycle.precondition {}` | Trước resource action (mỗi resource) | Mọi expression Terraform | Hard fail |
| `lifecycle.postcondition {}` | Sau resource action | `self.*` + mọi expression | Hard fail |
| Top-level `check {}` | Cuối plan/apply (best-effort) | Mọi expression | **Warning** only |

**Quy tắc thực dụng:**

- **Validation:** giới hạn input (range, regex, enum). Đắt nhất ~1 ms.
- **Precondition:** kiểm tra invariant cross-resource (vd: data source X phải
  tồn tại trước khi tạo resource Y). Refuses nếu sai.
- **Postcondition:** verify provider trả về đúng thứ kỳ vọng (vd: image_id
  populated, port bound). Bắt provider bug.
- **Check:** SLO-style monitoring (vd: latency < 100ms). Không stop apply.
  Dùng cho thông tin có thể đúng/sai tạm thời.

### Vì sao `check {}` là warning, không phải fail?

Triết lý "fail-soft": invariant như "tất cả service phải healthy" có thể
fail tạm thời do network blip — đừng block deploy. Thay vào đó, log warning,
để alerting/dashboard handle. `precondition`/`postcondition` là "fail-hard"
— nếu sai, có gì đó đã break thật.

### `self` keyword — quy tắc scope

- Trong `precondition` của resource X: `self` = **NOT YET CREATED**. Đừng
  reference `self.computed_attr` — sẽ unknown.
- Trong `postcondition` của resource X: `self` = **JUST CREATED**, mọi
  attribute available.
- Trong `variable.validation`: `var.<name>` reference biến đang validate,
  không có `self`.

### Validation: regex vs `contains` vs `alltrue`

```hcl
# Regex (chuỗi)
validation {
  condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name_prefix))
  error_message = "..."
}

# Enum (string)
validation {
  condition     = contains(["dev", "staging", "prod"], var.env)
  error_message = "env phải là dev/staging/prod."
}

# List validation
validation {
  condition     = alltrue([for p in var.ports : p >= 8000 && p <= 9999])
  error_message = "Mọi port phải trong [8000, 9999]."
}

# Cross-attribute (chỉ cho variable trả về object)
validation {
  condition     = var.config.min < var.config.max
  error_message = "min phải nhỏ hơn max."
}
```

### `can()` vs `try()`

- `can(expr)` → bool. True nếu expr không throw. Dùng trong `condition`.
- `try(expr, fallback)` → giá trị. Dùng để safe-extract nested fields.

```hcl
condition = can(regex(...))                    # ✓ check shape
condition = try(var.config.optional, true)     # ✗ wrong context, dùng for value
```

### Postcondition workflow — kết hợp với plan

```hcl
postcondition {
  condition     = self.image_id != ""
  error_message = "..."
}
```

Khi `terraform plan` chạy:
- Provider trả về "this will be created" + plan attributes.
- Plan attributes có thể unknown (chưa apply). Terraform chỉ check
  postcondition khi self attribute KNOWN.
- Sau apply, postcondition chạy với real values. Nếu fail → state có entry
  với "tainted" → apply tiếp theo sẽ recreate. Hơi phiền nhưng đúng semantic.

### Cạm bẫy thường gặp

1. **`validation { condition = var.x != "" }` với string không có default.**
   Empty string default → validation luôn fail. Set default thực tế hoặc
   loại bỏ check.
2. **`postcondition` reference attribute chưa known.** Plan sẽ fail với
   `"Postcondition referring to an unknown value"`. Solution: dùng
   `precondition` cho input, `postcondition` chỉ cho output.
3. **`check {}` block cho thứ thực sự cần fail-hard.** Vd: "secret được set".
   Đừng dùng check — dùng `precondition` để block apply.
4. **Variable validation cross-variable.** Terraform 1.9+ hỗ trợ; trước đó
   chỉ self. Đọc kỹ version requirements.
5. **`error_message` không kết thúc bằng dấu chấm.** Terraform validate
   warning. Style: 1 câu, dấu chấm cuối, mô tả "tại sao sai" + "expected".

### Bonus: 3 layer cùng phối hợp

Scenario: container expose service.

```hcl
variable "port" {
  validation { condition = var.port >= 1024 && var.port <= 65535 ... }
}

resource "docker_container" "x" {
  lifecycle {
    precondition  { condition = data.docker_network.x.id != "" ... }  # cross-resource
    postcondition { condition = self.ports[0].external == var.port ... }  # provider sanity
  }
}

check "service_healthy" {
  data "http" "ping" { url = "http://localhost:${var.port}/health" }
  assert {
    condition     = data.http.ping.status_code == 200
    error_message = "Service health check failed (port ${var.port})."
  }
}
```

→ Defense-in-depth: input → resource creation → integration health.

### Docs tham khảo

- Variable validation: <https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules>
- Custom conditions: <https://developer.hashicorp.com/terraform/language/expressions/custom-conditions>
- Precondition/Postcondition: <https://developer.hashicorp.com/terraform/language/expressions/custom-conditions#preconditions-and-postconditions>
- Check blocks: <https://developer.hashicorp.com/terraform/language/checks>

## 🆘 Bí quá?

Mở `HINTS.md` (theo bậc 1 → 2 → 3).
