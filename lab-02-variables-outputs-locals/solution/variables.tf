variable "image" {
  description = "Container image identified by name + tag. Tag MUST be pinned (no 'latest')."
  type = object({
    name = string
    tag  = string
  })
  default = {
    name = "nginx"
    tag  = "1.27-alpine"
  }

  validation {
    condition     = var.image.tag != "latest"
    error_message = "image.tag must be a pinned version, got 'latest' which is forbidden for reproducible builds."
  }
}

variable "service_name" {
  description = "Logical service name. Must be DNS-safe (a-z, 0-9, dash)."
  type        = string
  default     = "demo"

  validation {
    condition     = length(var.service_name) >= 3 && length(var.service_name) <= 32
    error_message = "service_name length must be between 3 and 32, got ${length(var.service_name)}."
  }

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "service_name must match ^[a-z0-9-]+$ (lowercase, digits, dashes), got '${var.service_name}'."
  }
}

variable "replicas" {
  description = "Number of container replicas to run for this service."
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 5
    error_message = "replicas must be between 1 and 5, got ${var.replicas}."
  }
}

variable "labels" {
  description = "Free-form labels applied to every container. Will be merged with managed_by=terraform."
  type        = map(string)
  default = {
    owner = "team-a"
    env   = "dev"
  }
}

variable "external_port_base" {
  description = "Host port for the first replica. Replica N listens on base + N."
  type        = number
  default     = 8082

  validation {
    condition     = var.external_port_base >= 8000 && var.external_port_base <= 9000
    error_message = "external_port_base must be in [8000, 9000], got ${var.external_port_base}."
  }
}

variable "admin_password" {
  description = "Admin password. If null, a random one is generated. Always treated as sensitive."
  type        = string
  default     = null
  sensitive   = true
}
