terraform {
  required_version = ">= 1.9.0"

  # Best practice: child modules declare only `required_providers` (with
  # source + version), NOT `provider {}` blocks. The root module owns provider
  # configuration. This makes the module reusable from any caller and avoids
  # the well-known "module-with-provider locks you out of refactoring" trap.
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
