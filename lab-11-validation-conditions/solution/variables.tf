variable "name_prefix" {
  description = "Prefix for container names. Must follow Docker name rules."
  type        = string
  default     = "tflab-11"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name_prefix))
    error_message = "name_prefix must start with a lowercase letter and contain only [a-z0-9-], length 3..31."
  }
}

variable "base_port" {
  description = "External port for the first container. Subsequent replicas use base_port+i."
  type        = number
  default     = 8221

  validation {
    condition     = var.base_port >= 8000 && var.base_port <= 9999
    error_message = "base_port must be in [8000, 9999] to avoid privileged ports and ephemeral range."
  }
}

variable "replicas" {
  description = "Number of nginx containers to create."
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 5
    error_message = "replicas must be in [1, 5] — keep the lab small."
  }
}
