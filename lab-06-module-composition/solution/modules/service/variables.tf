variable "name" {
  description = "Service name. Used as the container suffix and label value."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "name must match ^[a-z0-9-]+$, got '${var.name}'."
  }
}

variable "image" {
  description = "Container image including a pinned tag."
  type        = string

  validation {
    condition     = !endswith(var.image, ":latest")
    error_message = "image must not use ':latest', got '${var.image}'."
  }
}

variable "external_port" {
  description = "Base host port. Replica N listens on external_port + N."
  type        = number

  validation {
    condition     = var.external_port >= 1 && var.external_port <= 65500
    error_message = "external_port must be in [1, 65500], got ${var.external_port}."
  }
}

variable "network_name" {
  description = "Name of the existing Docker network to attach every replica to. Pass `module.network.name` from the root."
  type        = string
}

variable "replicas" {
  description = "Number of identical replicas (1..3). Each gets its own host port external_port + idx."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 3
    error_message = "replicas must be in [1, 3], got ${var.replicas}."
  }
}

variable "labels" {
  description = "Free-form labels applied to every container."
  type        = map(string)
  default     = {}
}

variable "healthcheck" {
  description = "Container HTTP healthcheck. Set enabled=false to skip."
  type = object({
    enabled  = bool
    interval = string
  })
  default = {
    enabled  = true
    interval = "10s"
  }
}
