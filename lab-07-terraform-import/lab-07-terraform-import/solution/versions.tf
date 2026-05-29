terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Default Docker provider — uses the local socket. The lab is intentionally
# single-provider: importing real Docker resources into Terraform state is the
# subject, not multi-region topology.
provider "docker" {}
