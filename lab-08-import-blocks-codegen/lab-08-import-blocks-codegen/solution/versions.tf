terraform {
  # `import {}` blocks were introduced in TF 1.5. We require 1.7 because
  # this lab uses `for_each` on import blocks (TF 1.7+). Codegen
  # (`-generate-config-out`) is available since 1.5.
  required_version = ">= 1.7.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "docker" {}
