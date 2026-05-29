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

provider "docker" {}

# TODO V1: thêm 2 provider docker với alias = "east" và "west".
# provider "docker" {
#   alias = "east"
# }
# provider "docker" {
#   alias = "west"
# }
