variable "workspace_config" {
  description = "Per-workspace settings; 'default' acts as fallback for any unknown workspace."
  type = map(object({
    port     = number
    replicas = number
  }))
  default = {
    default = { port = 8200, replicas = 1 }
    dev     = { port = 8201, replicas = 1 }
    prod    = { port = 8202, replicas = 2 }
  }
}
