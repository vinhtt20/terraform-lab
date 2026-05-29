# =====================================================================
# Lab 05 — module web_service — TODO: hoàn thiện file này.
#
# Khung dưới validate được, nhưng:
#   - Thiếu validation cho `name` (regex + length).
#   - Thiếu validation cho `image` (chặn :latest).
#   - Thiếu validation cho `external_port` (1..65535).
#   - Thiếu các biến optional `index_content`, `enable_log_volume`.
# =====================================================================

variable "name" {
  description = "Logical service name. Used as the container suffix."
  type        = string

  # TODO V1: thêm 2 validation:
  #   - khớp regex ^[a-z0-9-]+$
  #   - length trong [2, 32]
}

variable "image" {
  description = "Container image including the tag."
  type        = string

  # TODO V2: validation — KHÔNG cho tag == "latest".
  # Gợi ý: !endswith(var.image, ":latest")
}

variable "external_port" {
  description = "Host port to bind the container's port 80 to."
  type        = number

  # TODO V3: validation 1 <= x <= 65535.
}

variable "labels" {
  description = "Free-form labels merged into the container's label set."
  type        = map(string)
  default     = {}
}

# TODO V4: thêm variable "index_content" — type string, default null.
# Mô tả: optional HTML để serve làm /index.html.

# TODO V5: thêm variable "enable_log_volume" — type bool, default false.
# Mô tả: nếu true → tạo named docker volume mount vào /var/log/nginx.
