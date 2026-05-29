terraform {
  # Ephemeral resources / outputs require Terraform 1.10+.
  required_version = ">= 1.10.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}
