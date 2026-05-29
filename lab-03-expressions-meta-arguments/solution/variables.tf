variable "services" {
  description = "Map of services to deploy. Key = service name (DNS-safe)."
  type = map(object({
    image              = string
    external_port      = number
    env                = optional(map(string), {})
    enable_healthcheck = optional(bool, true)
  }))

  default = {
    alpha = {
      image         = "nginx:1.27-alpine"
      external_port = 8083
      env = {
        ROLE = "frontend"
        TEAM = "alpha"
      }
      enable_healthcheck = true
    }
    bravo = {
      image         = "nginx:1.27-alpine"
      external_port = 8084
      env = {
        ROLE = "api"
        TEAM = "bravo"
      }
      enable_healthcheck = true
    }
    charlie = {
      image         = "nginx:1.27-alpine"
      external_port = 8085
      env = {
        ROLE = "worker"
        TEAM = "charlie"
      }
      # Demonstrate the "off" path of the dynamic healthcheck block.
      enable_healthcheck = false
    }
  }

  validation {
    condition     = length(var.services) >= 1 && length(var.services) <= 10
    error_message = "services map must have 1..10 entries, got ${length(var.services)}."
  }
}

variable "global_labels" {
  description = "Labels merged into every container's labels."
  type        = map(string)
  default = {
    managed_by = "terraform"
    lab        = "tflab-03"
  }
}
