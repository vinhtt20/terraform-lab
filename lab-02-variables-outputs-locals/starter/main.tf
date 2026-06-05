# =====================================================================
# Lab 02 — TODO: hoàn thiện file này.
#
# Khung resource đã có nhưng:
#   - random_password chưa conditional (count = ...).
#   - locals chưa đầy đủ.
#   - docker_container chưa dùng for_each, ports chưa map đúng,
#     labels chưa dùng dynamic block.
#   - local_file.summary chưa ghi đúng nội dung JSON.
# =====================================================================

locals {
  container_name_prefix = "tflab-02-${var.service_name}"

  # TODO L1: merged_labels = merge(var.labels, { managed_by = "terraform" })
  merged_labels = merge(var.labels, { managed_by = "terraform" })

  # TODO L2: password_effective =
  #   coalesce(var.admin_password, try(random_password.admin[0].result, null))
  password_effective = coalesce(
    var.admin_password,
  try(random_password.admin[0].result, null))
}

# TODO M1: chỉ tạo random_password khi var.admin_password == null.
# Gợi ý: count = var.admin_password == null ? 1 : 0
resource "random_password" "admin" {
  length  = 20
  special = true
  count   = var.admin_password == null ? 1 : 0
}

resource "docker_image" "app" {
  # TODO M2: name = "${var.image.name}:${var.image.tag}"
  name         = "${var.image.name}:${var.image.tag}"
  keep_locally = true
}

# TODO M3: chuyển sang for_each trên toset([for i in range(var.replicas) : tostring(i)]).
# TODO M4: thay tên thành "${local.container_name_prefix}-${each.key}".
# TODO M5: external port = var.external_port_base + tonumber(each.key).
# TODO M6: labels qua dynamic block đọc từ local.merged_labels.
resource "docker_container" "app" {
  for_each = toset([for i in range(var.replicas) : tostring(i)])
  name     = "${local.container_name_prefix}-${each.key}"
  image    = docker_image.app.image_id

  ports {
    internal = 80
    external = var.external_port_base + tonumber(each.key)
  }

  dynamic "labels" {
    for_each = local.merged_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  restart = "unless-stopped"
}

# TODO M7: ghi JSON summary với các key: service, image, names, ports, labels.
# KHÔNG bao gồm password.
resource "local_file" "summary" {
  filename = "${path.module}/summary.json"
  content = jsonencode({
    service = var.service_name
    image   = "${var.image.name}:${var.image.tag}"
    names   = [for container in docker_container.app : container.name]
    ports   = [for container in docker_container.app : container.ports[0].external]
    labels  = local.merged_labels
  })
}
