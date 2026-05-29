# Hints — Lab 04

> Mỗi bậc bung dần. Tự thử trước khi mở bậc tiếp theo.

<details><summary>Bậc 1 — Nudge nhỏ</summary>

- Data source khai báo bằng từ khoá `data`, không phải `resource`. Tham chiếu thuộc tính
  qua `data.<type>.<name>.<attr>`.
- Tra docs `docker_registry_image` data source: attribute `.name` trả về `repo:tag`, còn
  `.sha256_digest` là `sha256:...`. Để pin theo digest, ghép chuỗi
  `"${data.docker_registry_image.nginx.name}@${data.docker_registry_image.nginx.sha256_digest}"`.
- Trong file `versions.tf`, có thể có **nhiều** `provider "docker" {}` block — phân biệt bằng
  `alias`. Resource chọn alias qua meta-argument `provider = docker.<alias>`.
- `count` trên data source: cho phép bật/tắt data source mà không cần xoá khỏi file.
- `try(...)`: bọc biểu thức có thể fail (vì index không tồn tại) → trả `null` thay vì crash.

</details>

<details><summary>Bậc 2 — Hướng đi</summary>

**Khai báo data sources:**

```hcl
data "docker_registry_image" "nginx" {
  name = "nginx:1.27-alpine"
}

data "local_file" "motd" {
  filename = "${path.module}/files/motd.txt"
}

data "http" "geoip" {
  count              = var.enable_geoip ? 1 : 0
  url                = "https://ipinfo.io/json"
  request_timeout_ms = 5000
}
```

**Provider alias trong versions.tf:**

```hcl
provider "docker" {}                # default
provider "docker" { alias = "east" }
provider "docker" { alias = "west" }
```

**Gắn provider vào resource (và pin digest):**

```hcl
resource "docker_image" "east" {
  provider     = docker.east
  name         = "${data.docker_registry_image.nginx.name}@${data.docker_registry_image.nginx.sha256_digest}"
  keep_locally = true
}

resource "docker_container" "east" {
  provider = docker.east
  # ...
}
```

**Labels gồm hash MOTD:**

```hcl
labels {
  label = "motd_sha256"
  value = substr(sha256(data.local_file.motd.content), 0, 16)
}
```

`substr(x, 0, 16)` lấy 16 ký tự đầu — đủ cho label, không quá dài.

**Output sensitive cho geoip:**

```hcl
output "geoip" {
  value     = try(data.http.geoip[0].response_body, null)
  sensitive = true
}
```

</details>

<details><summary>Bậc 3 — Gần đáp án</summary>

```hcl
# versions.tf — thêm 2 provider alias
provider "docker" { alias = "east" }
provider "docker" { alias = "west" }
```

```hcl
# main.tf
data "docker_registry_image" "nginx" {
  name = "nginx:1.27-alpine"
}

data "local_file" "motd" {
  filename = "${path.module}/files/motd.txt"
}

data "http" "geoip" {
  count              = var.enable_geoip ? 1 : 0
  url                = "https://ipinfo.io/json"
  request_timeout_ms = 5000
}

resource "docker_image" "east" {
  provider     = docker.east
  name         = data.docker_registry_image.nginx.name
  keep_locally = true
}

resource "docker_container" "east" {
  provider = docker.east

  name  = "tflab-04-east"
  image = docker_image.east.image_id

  ports {
    internal = 80
    external = 8090
  }

  labels {
    label = "region"
    value = "east"
  }
  labels {
    label = "motd_sha256"
    value = substr(sha256(data.local_file.motd.content), 0, 16)
  }

  restart = "unless-stopped"
}

# west tương tự, đổi provider, port, region label.
```

```hcl
# outputs.tf
output "digest" {
  value = data.docker_registry_image.nginx.sha256_digest
}

output "motd_sha256" {
  value = sha256(data.local_file.motd.content)
}

output "geoip" {
  value     = try(data.http.geoip[0].response_body, null)
  sensitive = true
}
```

**Câu hỏi tự kiểm:** Tại sao `enable_geoip = false` là default? — Vì data source `http` chạy
ở plan time, gọi network. Bật mặc định = CI cần network mỗi lần plan → flaky. Pattern chung:
**network call optional, opt-in qua flag**.

</details>
