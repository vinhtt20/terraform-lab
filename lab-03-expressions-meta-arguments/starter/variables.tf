# =====================================================================
# Lab 03 — TODO: hoàn thiện biến `services`.
#
# Khung dưới đã validate, nhưng default đang là MAP RỖNG. Bạn phải điền
# 3 service ví dụ theo README (alpha:8083, bravo:8084, charlie:8085).
# =====================================================================

variable "services" {
  description = "Map of services to deploy."
  type = map(object({
    image              = string
    external_port      = number
    env                = optional(map(string), {})
    enable_healthcheck = optional(bool, true)
  }))

  # TODO 1: thêm 3 service alpha/bravo/charlie với env phù hợp.
  default = {}
}

variable "global_labels" {
  description = "Labels merged into every container."
  type        = map(string)
  default = {
    managed_by = "terraform"
    lab        = "tflab-03"
  }
}
