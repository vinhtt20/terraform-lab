terraform {
  required_version = ">= 1.9.0"

  # The network module is region-agnostic — it does not need provider
  # aliases. A single implicit `docker` provider from the root is enough.
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
