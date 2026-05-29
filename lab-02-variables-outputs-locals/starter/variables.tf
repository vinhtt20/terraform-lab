# =====================================================================
# Lab 02 — TODO: hoàn thiện file này.
#
# Khung dưới đã validate, nhưng:
#   - Một số biến đang thiếu validation block (TODO).
#   - Một số default đang sai (TODO).
#   - admin_password chưa được đánh dấu sensitive (TODO).
#
# Đọc README "Yêu cầu cụ thể" và điền vào.
# =====================================================================

variable "image" {
  description = "Container image identified by name + tag."
  type = object({
    name = string
    tag  = string
  })
  default = {
    name = "nginx"
    tag  = "1.27-alpine"
  }

  # TODO 1: thêm validation chặn tag == "latest", với error_message hữu ích.
  # validation {
  #   condition     = ...
  #   error_message = "..."
  # }
}

variable "service_name" {
  description = "Logical service name (DNS-safe: a-z, 0-9, dash)."
  type        = string
  default     = "demo"

  # TODO 2: thêm 2 validation:
  #   - length trong [3, 32]
  #   - khớp regex ^[a-z0-9-]+$
}

variable "replicas" {
  description = "Number of container replicas."
  type        = number
  default     = 2

  # TODO 3: thêm validation 1 <= var.replicas <= 5.
}

variable "labels" {
  description = "Free-form labels applied to every container."
  type        = map(string)
  default = {
    owner = "team-a"
    env   = "dev"
  }
}

variable "external_port_base" {
  description = "Host port for first replica. Replica N uses base + N."
  type        = number
  default     = 8082

  # TODO 4: thêm validation 8000 <= var.external_port_base <= 9000.
}

variable "admin_password" {
  description = "Admin password. If null, a random one is generated."
  type        = string
  default     = null
  # TODO 5: đánh dấu sensitive = true.
}
