variable "rotation_id" {
  description = "Opaque identifier; changing this forces the container to be replaced."
  type        = string
  default     = "v1"
}

variable "external_port" {
  description = "External port for the container."
  type        = number
  default     = 8241
}
