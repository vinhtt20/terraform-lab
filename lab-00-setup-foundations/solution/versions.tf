terraform {
  required_version = ">= 1.9.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Default Docker provider talks to the local Docker daemon via the Unix socket.
# Override DOCKER_HOST in the environment if you need a remote engine.
provider "docker" {}
