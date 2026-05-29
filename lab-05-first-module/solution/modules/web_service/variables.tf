variable "name" {
  description = "Logical service name. Used as the container suffix and label value. Must be DNS-safe."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "name must match ^[a-z0-9-]+$ (lowercase, digits, dashes), got '${var.name}'."
  }

  validation {
    condition     = length(var.name) >= 2 && length(var.name) <= 32
    error_message = "name length must be in [2, 32], got ${length(var.name)}."
  }
}

variable "image" {
  description = "Container image including the tag. Tag MUST be pinned (no 'latest')."
  type        = string

  validation {
    condition     = !endswith(var.image, ":latest") && length(regexall(":", var.image)) >= 1
    error_message = "image must include a non-'latest' tag (e.g. 'nginx:1.27-alpine'), got '${var.image}'."
  }
}

variable "external_port" {
  description = "Host port to bind the container's port 80 to."
  type        = number

  validation {
    condition     = var.external_port >= 1 && var.external_port <= 65535
    error_message = "external_port must be in [1, 65535], got ${var.external_port}."
  }
}

variable "labels" {
  description = "Free-form labels merged into the container's label set. `managed_by=terraform` is always added."
  type        = map(string)
  default     = {}
}

variable "index_content" {
  description = "Optional HTML to serve as /index.html. When null, the image's default page is kept."
  type        = string
  default     = null
}

variable "enable_log_volume" {
  description = "When true, create a named Docker volume and mount it at /var/log/nginx for log persistence."
  type        = bool
  default     = false
}
