terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # Explicit local backend. Even though "local" is Terraform's default, declaring
  # it (a) documents intent in PR review and (b) is the only way to customize
  # state path via `terraform init -backend-config=...` later if needed.
  backend "local" {}
}

provider "docker" {}
