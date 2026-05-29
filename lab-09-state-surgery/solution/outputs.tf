output "urls" {
  description = "Public URLs of managed containers, keyed by app name."
  value = {
    for k, c in docker_container.web : k => "http://localhost:${c.ports[0].external}"
  }
}
