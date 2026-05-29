terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Default Docker provider — used by the network module (regionless infra).
provider "docker" {}

# Aliased providers simulate two "regions". In real life these would point at
# different DOCKER_HOST endpoints (or AWS regions, GCP projects, …). The host
# is omitted on purpose so all three share the same local daemon — this lab is
# about the *syntax* of passing aliases to modules, not the topology.
provider "docker" {
  alias = "east"
}

provider "docker" {
  alias = "west"
}
