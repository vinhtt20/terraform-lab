# User-defined bridge network — both containers attach to this one
# so they can reach each other by container name (DNS via Docker).
resource "docker_network" "app" {
  name = "tflab-01-net"
}

# Image resources kept separate from containers for lifecycle isolation
# (see Lab 00 "Đào sâu"). Pinned tags — never use :latest in lab code.
resource "docker_image" "redis" {
  name         = "redis:7-alpine"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# "db" container — simulated database (redis is enough to demonstrate
# ordering; we don't need real persistence in this lab).
#
# Implicit dependency: `image = docker_image.redis.image_id` and the
# networks_advanced reference to docker_network.app already wire this
# resource to its dependencies — Terraform infers the graph automatically.
resource "docker_container" "db" {
  name  = "tflab-01-db"
  image = docker_image.redis.image_id

  networks_advanced {
    name = docker_network.app.name
  }

  restart = "unless-stopped"
}

# "web" container — nginx serving on host port 8081.
#
# We intentionally add `depends_on = [docker_container.db]` even though
# there's no attribute reference from web → db. This is the canonical
# place to teach EXPLICIT dependency: business logic says "web must come
# up after db", but Terraform can't infer that from references alone.
resource "docker_container" "web" {
  name  = "tflab-01-web"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.app.name
  }

  ports {
    internal = 80
    external = 8081
  }

  restart = "unless-stopped"

  depends_on = [docker_container.db]
}
