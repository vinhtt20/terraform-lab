# Hints — Lab 13

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- Rego file PHẢI có `package` declaration ở đầu (vd: `package main`).
- `deny[msg]` là set rule — mỗi binding `msg` thỏa điều kiện sẽ là 1 violation.
- `input` là Terraform plan JSON. Đường dẫn cho mọi resource:
  `input.planned_values.root_module.resources[_]`. `_` = "bất kỳ index".
- Docker provider lưu labels dạng **list of objects**:
  `resource.values.labels = [{label, value}, ...]`. Convert qua comprehension.
- `sprintf` builtin Rego: `sprintf("format %v %s", [arg1, arg2])` (list, không phải varargs).

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**`policies/no_latest_tag.rego` — 2 rules:**

```rego
package main

# Rule 1: deny :latest
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "docker_image"
    endswith(resource.values.name, ":latest")
    msg := sprintf("docker_image %q uses :latest tag.", [resource.address])
}

# Rule 2: deny no-tag (no ":" in name)
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "docker_image"
    not contains(resource.values.name, ":")
    msg := sprintf("docker_image %q has no explicit tag.", [resource.address])
}
```

**`policies/require_owner_label.rego` — 1 rule:**

```rego
package main

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "docker_container"
    labels := { entry.label | entry := resource.values.labels[_] }
    not labels["owner"]
    msg := sprintf("docker_container %q missing required label 'owner'.",
                   [resource.address])
}
```

**Test workflow:**

```bash
cd starter
terraform init
bash ci-check.sh          # passes (config sạch)

# Inject violation
echo 'resource "docker_image" "bad" { name = "alpine:latest" keep_locally = true }' > /tmp/v.tf
cp /tmp/v.tf .
bash ci-check.sh          # FAILS với :latest violation
rm v.tf
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

**`policies/no_latest_tag.rego` hoàn chỉnh:**

```rego
package main

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "docker_image"
    endswith(resource.values.name, ":latest")
    msg := sprintf("docker_image %q uses :latest tag — forbidden by policy.",
                   [resource.address])
}

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "docker_image"
    not contains(resource.values.name, ":")
    msg := sprintf("docker_image %q has no explicit tag — must pin a version.",
                   [resource.address])
}
```

**`policies/require_owner_label.rego` hoàn chỉnh:**

```rego
package main

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "docker_container"
    labels := { entry.label | entry := resource.values.labels[_] }
    not labels["owner"]
    msg := sprintf("docker_container %q missing required label 'owner'.",
                   [resource.address])
}
```

**Câu hỏi tự kiểm:**

> Tôi viết policy nhưng `conftest test` báo "0 failures" mặc dù tôi nghĩ
> nên có violation. Vì sao?

3 nguyên nhân phổ biến:
1. Quên `package main` → conftest skip file.
2. Rule không match — `resource.type` viết sai chính tả (vd: `docker_images`).
3. `not labels.owner` mà labels chưa được bind → undefined → rule không apply.

> Tôi muốn chỉ `warn` chứ không `deny` cho 1 policy. Cách làm?

Đổi `deny[msg]` → `warn[msg]`. Conftest exit 0 nhưng print message.

> Plan JSON quá lớn để đọc. Cách xem cấu trúc nhanh?

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq '.planned_values.root_module.resources[] | {address, type, values}'
```

> Tôi muốn policy chỉ apply cho 1 môi trường (vd: prod). Cách?

Đọc `terraform.workspace` qua... không, plan JSON không có workspace. Workaround:
- Pass `--data env=prod` cho conftest CLI.
- Hoặc tag resource với label/tag `env=prod` và policy check label.
- Hoặc tách policies/dev.rego và policies/prod.rego + chỉ load thư mục đúng.

> `child_modules` của tôi không bị check. Vì sao?

Policy iterate `input.planned_values.root_module.resources[_]` chỉ thấy
root. Để xuống module: thêm rule `input.planned_values.root_module.child_modules[_].resources[_]`,
hoặc dùng helper recursive (xem README "Đào sâu").

> Tôi cài conftest qua brew xong báo "command not found".

`/opt/homebrew/bin/conftest` (M-series Mac) vs `/usr/local/bin/conftest`
(Intel Mac). Add brew bin vào PATH:
`export PATH="/opt/homebrew/bin:$PATH"`. Hoặc `brew doctor` chỉ ra path.

</details>
