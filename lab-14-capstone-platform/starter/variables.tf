variable "services" {
  description = "Map of service definitions to deploy. Key = service name."
  type = map(object({
    port      = number
    owner     = string
    image_tag = optional(string, "nginx:1.27-alpine")
  }))

  default = {
    api = {
      port  = 8281
      owner = "platform-team"
    }
    web = {
      port  = 8282
      owner = "frontend-team"
    }
  }

  validation {
    condition     = length(var.services) >= 1 && length(var.services) <= 10
    error_message = "services map must contain 1..10 entries."
  }

  validation {
    condition     = length(distinct([for s in var.services : s.port])) == length(var.services)
    error_message = "All service ports must be unique."
  }
}
