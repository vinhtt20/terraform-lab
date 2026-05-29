variable "name" {
  description = "Docker network name. Must be DNS-safe."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]*$", var.name))
    error_message = "name must match ^[a-z0-9][a-z0-9_-]*$, got '${var.name}'."
  }
}

variable "labels" {
  description = "Free-form labels applied to the network. `managed_by=terraform` is always added."
  type        = map(string)
  default     = {}
}
