terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

# Default Docker provider — used by data sources that don't specify an alias.
provider "docker" {}

# Aliased providers simulate two "regions". In real life these would point at
# different DOCKER_HOST endpoints (or AWS regions, GCP projects, etc.).
# The `host` is omitted on purpose so all three share the same local daemon —
# this lab is about the SYNTAX of multi-provider, not the topology.
provider "docker" {
  alias = "east"
}

provider "docker" {
  alias = "west"
}
