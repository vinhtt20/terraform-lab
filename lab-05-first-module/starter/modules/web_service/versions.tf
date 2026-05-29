terraform {
  required_version = ">= 1.9.0"

  # Best practice: child module declares only required_providers — NO
  # `provider {}` block here. Root passes its provider in implicitly.
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
