terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"

      # KEY CONCEPT: `configuration_aliases` declares that this module accepts
      # an aliased provider passed in by the caller. Without this, the root
      # cannot do `providers = { docker = docker.east }` — Terraform will say
      # "Provider mismatch". The alias name (`target`) is used INSIDE the
      # module as `provider = docker.target`.
      configuration_aliases = [docker.target]
    }
  }
}
