variable "image" {
  description = "Container image (with pinned tag) used by every module call."
  type        = string
  default     = "nginx:1.27-alpine"

  validation {
    condition     = !endswith(var.image, ":latest")
    error_message = "image must be pinned to a non-'latest' tag, got '${var.image}'."
  }
}
