# CONVENTIONS — chuẩn soạn lab (đọc kỹ trước khi viết)

Tài liệu này là **hợp đồng** mà mọi lab phải tuân theo. Người chấm sẽ dựa vào đây để đánh giá tính
nhất quán giữa các lab. Bất kỳ lệch chuẩn nào cần ghi chú lý do ở đầu file lab.

---

## 1. Cấu trúc bắt buộc mỗi lab

```
lab-NN-topic/
├── README.md           # ĐỀ BÀI cho người học
├── starter/            # khung khởi đầu có TODO; người học làm trực tiếp tại đây
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── solution/           # lời giải tham chiếu chuẩn (fmt sạch, validate pass)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── terraform.tfvars.example
├── verify.sh           # script chấm tự động — exit 0=PASS, 1=FAIL
└── HINTS.md            # gợi ý 3 bậc (bung dần)
```

Lab nào không cần `variables.tf`/`outputs.tf` ở mức starter thì bỏ file, không để file rỗng.

---

## 2. Khối `versions.tf` chuẩn (copy-paste)

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

# Docker provider mặc định: dùng socket cục bộ; lab nâng cao có thể override.
provider "docker" {}
```

- Chỉ khai báo `required_providers` cho provider **thực sự dùng** trong lab.
- **Ngoại lệ:** `lab-12-testing-lifecycle` dùng `ephemeral` → nâng `required_version = ">= 1.10.0"`.
- **Ngoại lệ:** `lab-08-import-blocks-codegen` dùng `import {}` + codegen → cần `>= 1.5.0` (mặc định OK).

---

## 3. Template README.md cho mỗi lab

```markdown
# Lab NN — <Tên>

> **Cấp độ:** Cơ bản | Trung cấp | Nâng cao | Expert
> **Thời lượng dự kiến:** 30–45 phút
> **Yêu cầu trước:** Lab XX

## 🎯 Mục tiêu học
Liệt kê 3–6 mục tiêu, mỗi mục có động từ đo được (sử dụng được X, giải thích được Y, refactor được Z).

## 🌐 Bối cảnh
1–2 đoạn kịch bản thực tế: bạn là kỹ sư trong tình huống... cần phải...

## 📋 Yêu cầu cụ thể
Liệt kê dạng checklist các deliverable. Mỗi yêu cầu phải đo được bằng `verify.sh`.

- [ ] Yêu cầu 1...
- [ ] Yêu cầu 2...

## ✅ Tiêu chí pass
- Lệnh `terraform fmt -check -recursive` không sửa file nào.
- Lệnh `terraform validate` exit code 0.
- Lệnh `bash verify.sh` in `PASS` và exit code 0.
- Output yêu cầu khớp regex/giá trị mong đợi.

## 🧭 Hướng dẫn làm
1. `cd starter`
2. Đọc các comment `# TODO` trong code; điền vào.
3. `terraform init && terraform plan && terraform apply`
4. Quay về thư mục lab và chạy `bash verify.sh`.
5. Khi pass: `cd starter && terraform destroy` để dọn dẹp.

## 🧠 Đào sâu (expert)
Giải thích "vì sao" của khái niệm chính, 2–4 cạm bẫy thường gặp, link tới docs HashiCorp.

## 🆘 Bí quá?
Xem `HINTS.md` (mở từng bậc, đừng nhảy thẳng xuống bậc 3).
```

---

## 4. Quy tắc code Terraform (cho cả starter & solution)

1. **Đặt tên:** snake_case, danh từ số ít cho resource (`docker_container.web`, không phải `webs`).
2. **`fmt`:** mọi file phải `terraform fmt -check` sạch.
3. **`validate`:** solution phải `terraform validate` pass.
4. **Không hardcode secret/chuỗi nhạy cảm.** Dùng `random_password`, `sensitive = true`, hoặc env var.
5. **Không dùng `local-exec`/provisioner** trừ khi đó là chủ đề được dạy (lab dạy provisioner và cảnh báo
   phải có dòng "đây là anti-pattern; production hãy ưu tiên cách khác").
6. **Không dùng `-target`** trong solution hay verify trừ khi đang dạy nó (lab 10).
7. **Module trong `solution/`:** không đặt `provider {}` block bên trong module con (best practice).
8. **`required_version` & `required_providers`** phải có ở mọi lab.
9. **Comment trong code:** tiếng Anh, ngắn gọn, giải thích "tại sao" chứ không lặp lại "cái gì".
10. **Output sensitive:** đánh dấu `sensitive = true` khi cần (lab 02 trở đi).

---

## 5. Hợp đồng `verify.sh`

Template chung:

```bash
#!/usr/bin/env bash
# verify.sh — chấm tự động lab NN
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab NN — verify"

# 1. fmt
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null; then
  pass "terraform fmt sạch"
else
  fail "terraform fmt phát hiện file chưa format"
fi

# 2. validate (yêu cầu init trước)
if [[ ! -d "${WORK_DIR}/.terraform" ]]; then
  terraform -chdir="${WORK_DIR}" init -input=false -no-color >/dev/null
fi
if terraform -chdir="${WORK_DIR}" validate -no-color >/dev/null; then
  pass "terraform validate pass"
else
  fail "terraform validate thất bại"
fi

# 3. assert state / docker / outputs ... (tùy lab)
# Ví dụ:
# state=$(terraform -chdir="${WORK_DIR}" state list)
# echo "${state}" | grep -q 'docker_container.web' && pass "có resource docker_container.web" \
#                                                  || fail "thiếu docker_container.web"

echo
echo "Kết quả: ${PASS} pass, ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
```

- **Idempotent:** chạy lại nhiều lần không hỏng môi trường.
- **Self-contained:** không phụ thuộc biến môi trường ngoài (trừ lab dạy biến môi trường).
- **Cleanup tùy chọn:** mặc định KHÔNG `destroy` sau verify (người học tự dọn). Nếu lab cần, hỏi
  thông qua biến `CLEANUP=1`.

---

## 6. HINTS.md — 3 bậc

```markdown
# Hints — Lab NN

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

Một câu hỏi gợi mở, ví dụ: "Resource Docker `kreuzwerker/docker_container` có thuộc tính nào dùng
để map cổng?"

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

Mô tả cách tiếp cận, không dán code. Ví dụ: "Khai báo block `ports` với `internal` và `external`,
sau đó tham chiếu image qua `docker_image.X.image_id`."

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

Pseudo-code hoặc skeleton có 1–2 chỗ trống. Vẫn không phải lời giải đầy đủ — lời giải nằm ở
`solution/`.

</details>
```

---

## 7. Quy ước commit message (khi build)

`labNN: <hành động ngắn>` — ví dụ `lab07: add classic terraform import exercise`. Foundation file
dùng prefix `chore:`.

---

## 8. Anti-pattern cấm dùng (trừ khi dạy)

- Provisioner `remote-exec`/`local-exec` để tạo resource thật (dùng resource đúng provider).
- `terraform apply -auto-approve` trong hướng dẫn (trừ verify script).
- `null_resource` để "fake" dependency (dùng `depends_on` hoặc `terraform_data`).
- Hardcode đường dẫn tuyệt đối; mọi path qua `path.module`/`path.root`.
- `count` trên resource sẽ thay đổi thứ tự (dùng `for_each` với key ổn định).
- Module có `provider {}` block bên trong (truyền qua `providers = {}` khi cần alias).

---

## 9. Tài liệu tham chiếu (link trong README "Đào sâu")

- Terraform Language: https://developer.hashicorp.com/terraform/language
- Docker provider: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
- `terraform import`: https://developer.hashicorp.com/terraform/cli/import
- `import {}` block: https://developer.hashicorp.com/terraform/language/import
- State mgmt CLI: https://developer.hashicorp.com/terraform/cli/state
- `moved`/`removed`: https://developer.hashicorp.com/terraform/language/modules/develop/refactoring
- `terraform test`: https://developer.hashicorp.com/terraform/language/tests
- Ephemeral: https://developer.hashicorp.com/terraform/language/values/ephemeral
- Conftest/OPA: https://www.conftest.dev/

---

## 10. Checklist tự kiểm khi soạn xong 1 lab

- [ ] README đúng template (mục tiêu / bối cảnh / yêu cầu / pass / hướng dẫn / đào sâu).
- [ ] `versions.tf` có `required_version` + `required_providers` đúng version pin.
- [ ] `solution/` `terraform fmt -check` sạch.
- [ ] `solution/` `terraform validate` pass.
- [ ] `verify.sh` exit 0 khi chạy trên `solution/` (mô phỏng người học làm xong).
- [ ] `HINTS.md` có 3 bậc, không lộ đáp án ở bậc 1–2.
- [ ] Không vi phạm Anti-pattern (mục 8).
- [ ] Có mục "Đào sâu (expert)" và link docs chính thức.
