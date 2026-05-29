variable "name" {
  description = "Service name (also used as container name suffix)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must start with lowercase letter, [a-z0-9-], 2..31 chars."
  }
}

variable "port" {
  description = "External port the service listens on."
  type        = number

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "port must be in [1024, 65535]."
  }
}

variable "owner" {
  description = "Team owning this service. Stamped as label for cost-attribution."
  type        = string

  validation {
    condition     = length(var.owner) > 0
    error_message = "owner must be non-empty."
  }
}

variable "image_tag" {
  description = "Docker image tag — must be explicit (no :latest)."
  type        = string
  default     = "nginx:1.27-alpine"

  validation {
    condition     = !endswith(var.image_tag, ":latest")
    error_message = "image_tag must not be :latest. Pin a specific version."
  }
}
