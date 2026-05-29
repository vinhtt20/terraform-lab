variable "enable_geoip" {
  description = "When true, fetch geoip info via the http data source. Off by default to avoid network dependency in CI."
  type        = bool
  default     = false
}
