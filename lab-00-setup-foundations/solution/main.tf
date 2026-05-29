# Pull the nginx image as its own resource so Terraform manages the image
# lifecycle independently from the container (see "Đào sâu" in README.md).
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# A single nginx container exposed on host port 8080.
resource "docker_container" "hello" {
  name  = "tflab-00-hello"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }

  restart = "unless-stopped"
}
