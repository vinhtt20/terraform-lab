variable "name_prefix" {
  description = "Prefix for container names. Must follow Docker name rules."
  type        = string
  default     = "tflab-11"

  # TODO — add a validation block that ensures `name_prefix`:
  #   - starts with a lowercase letter
  #   - only contains lowercase letters, digits, and dashes
  #   - is between 3 and 31 characters long
  #
  # Hint: `can(regex("^[a-z][a-z0-9-]{2,30}$", var.name_prefix))`
}

variable "base_port" {
  description = "External port for the first container. Subsequent replicas use base_port+i."
  type        = number
  default     = 8221

  # TODO — validation: base_port must be in [8000, 9999].
}

variable "replicas" {
  description = "Number of nginx containers to create."
  type        = number
  default     = 2

  # TODO — validation: replicas must be in [1, 5].
}
