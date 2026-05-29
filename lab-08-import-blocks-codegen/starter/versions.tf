terraform {
  # `import {}` block + `for_each` on import requires TF >= 1.7.
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
