variable "enable_geoip" {
  description = "Toggle external HTTP fetch. Off by default for CI hygiene."
  type        = bool
  default     = false
}
