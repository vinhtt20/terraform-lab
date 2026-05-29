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

provider "docker" {}

# TODO: trong giải pháp cuối, root sẽ cần 2 provider alias `east` và `west`
# để truyền vào module "service". Hiện tại monolith chưa cần.
# provider "docker" { alias = "east" }
# provider "docker" { alias = "west" }
