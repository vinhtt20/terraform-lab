variable "owner" {
  description = "Owning team. Required by policy 'require_owner_label.rego'."
  type        = string
  default     = "platform-team"
}

variable "external_port" {
  description = "External port for the container."
  type        = number
  default     = 8261
}
