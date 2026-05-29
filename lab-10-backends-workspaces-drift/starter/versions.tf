terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # TODO — make the local backend EXPLICIT.
  # Even though "local" is Terraform's default backend, declaring it makes the
  # intent visible in code review and is the only way to customize state path.
  #
  # backend "local" {}
}

provider "docker" {}
