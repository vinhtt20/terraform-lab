# RUBRIC — Chấm điểm chuyên gia

Tài liệu này dành cho **chuyên gia review** chấm điểm chất lượng bài làm của người học (bổ sung
cho `verify.sh` vốn chỉ pass/fail). Mỗi lab chấm trên thang **100 điểm**, capstone trên **200**.

## Thang điểm chung (mọi lab)

| Tiêu chí | Trọng số | Mô tả |
|----------|----------|-------|
| **Correctness** | 40 | `verify.sh` pass; output đúng; resource thực sự tồn tại theo yêu cầu |
| **Idiomatic Terraform** | 20 | `fmt`/`validate` sạch; đặt tên chuẩn; không anti-pattern (xem CONVENTIONS §8) |
| **State hygiene** | 15 | Không rác trong state; refactor dùng `moved` thay vì `state mv` tay khi có thể; không phụ thuộc `-target` |
| **Readability & docs** | 15 | Comment giải thích "tại sao"; output rõ; README cá nhân (nếu lab yêu cầu) trả lời đúng câu hỏi |
| **Robustness** | 10 | `plan` lần 2 không drift; idempotent; xử lý input sai gracefully |

Điểm: `≥90 = Xuất sắc` · `80–89 = Tốt` · `70–79 = Đạt` · `<70 = Cần làm lại`.

## Bộ tiêu chí riêng theo Level

### Level 0–1 (Lab 00–04) — cơ bản/trung cấp
Trừ điểm nặng nếu:
- Hardcode giá trị nhẽ ra phải qua biến (`-5` mỗi vi phạm).
- Không có `required_version` / `required_providers` (`-10`).
- Dùng `count` khi `for_each` rõ ràng đúng hơn (`-5`).

### Level 2 (Lab 05–06) — modules
Trừ nặng nếu:
- Module có `provider {}` block bên trong (`-15` — sai best practice nghiêm trọng).
- Output module để lộ giá trị sensitive không `sensitive = true` (`-10`).
- Đường dẫn module dùng đường dẫn tuyệt đối (`-10`).
- Không có README riêng cho module (`-5`).

### Level 3 (Lab 07–10) — state mastery (TRỌNG TÂM IMPORT)

| Tiêu chí cộng thêm | Trọng số |
|---|---|
| Import đúng resource ID & đúng `terraform_address` | +20 |
| Hai lần `plan` liên tiếp sau import: lần đầu có thể đổi attribute, lần hai phải **0 changes** | +15 |
| Dùng `moved {}` khi refactor thay vì `state mv` lệnh (lab 09) | +10 |
| Có `removed {}` block khi xoá resource khỏi config mà giữ ngoài đời thật (lab 09) | +10 |
| Workspace dùng đúng (không lạm dụng workspace cho multi-env nếu quy mô lớn) | +5 |

Trừ nặng:
- Edit file `terraform.tfstate` bằng tay (`-30` — vi phạm nguyên tắc nghiêm trọng).
- Dùng `terraform destroy` để "sửa" state (`-20`).
- Không backup state trước surgery (`-10`).

### Level 4 (Lab 11–13) — expert

| Tiêu chí | Trọng số |
|---|---|
| `validation` block có error message hữu ích (chỉ rõ giá trị sai) | +5 |
| `precondition`/`postcondition` đặt đúng chỗ (precondition ở consumer, postcondition ở producer) | +10 |
| `check {}` block độc lập với apply (không break apply khi assert fail) | +5 |
| `terraform test` có cả `command = plan` và `command = apply` tests | +10 |
| Policy Rego có `deny` rõ message, có ít nhất 2 rule, có `_test.rego` đi kèm | +15 |
| Pipeline gating: plan→policy→apply, fail-fast khi policy violation | +10 |

### Capstone (Lab 14) — thang 200

Áp dụng toàn bộ tiêu chí trên + bổ sung:

| Tiêu chí | Trọng số |
|---|---|
| Phân tách module hợp lý (mỗi module 1 trách nhiệm) | 20 |
| Có ít nhất 2 resource import từ Docker tạo trước (hands-on) | 20 |
| `terraform test` có ≥ 4 test scenarios (happy + 2 edge + 1 negative) | 20 |
| Policy có ≥ 3 rule (vd: image tag không phải `latest`, container có healthcheck, network không default) | 20 |
| `MIGRATION.md` ghi chi tiết các bước nếu refactor (dùng `moved`) | 10 |
| `RUNBOOK.md` xử lý drift: phát hiện → triage → remediate | 10 |
| 2 lần `plan` liên tiếp → 0 changes | 15 |
| Đóng gói gọn: 1 lệnh `make up` hoặc tương đương | 5 |

## Cách chuyên gia review một bài

1. Clone bài làm, chạy `bash scripts/check-env.sh`.
2. Chạy `bash verify.sh` ở thư mục lab cần chấm — đây là cổng tối thiểu.
3. Mở `solution/` riêng cho mình; **không** đọc khi đang chấm.
4. Đọc code người học, đối chiếu rubric ở trên.
5. Ghi điểm + nhận xét theo từng tiêu chí.
6. **Bắt buộc viết lại 1 đoạn "Điều người học làm tốt nhất" + 1 đoạn "Điểm cần cải thiện".**

## Chống gian lận / chống "copy solution"

- Hỏi miệng: yêu cầu người học giải thích lý do chọn `for_each` thay vì `count` ở chỗ X.
- Hỏi: nếu ta đổi 1 attribute Y, output Z có thay đổi không? Vì sao?
- Yêu cầu refactor nhỏ tại chỗ (vd: tách module, đổi naming).
