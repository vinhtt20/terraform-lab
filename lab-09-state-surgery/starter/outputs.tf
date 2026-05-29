# BEFORE refactor — three independent outputs.
# AFTER refactor — collapse into ONE map output keyed by container name.
#
# Replace the three outputs below with:
#
#   output "urls" {
#     description = "Public URLs of managed containers."
#     value = {
#       for k, c in docker_container.web : k => "http://localhost:${c.ports[0].external}"
#     }
#   }

output "web1_url" {
  value = "http://localhost:${docker_container.web1.ports[0].external}"
}

output "web2_url" {
  value = "http://localhost:${docker_container.web2.ports[0].external}"
}

output "web3_url" {
  value = "http://localhost:${docker_container.web3.ports[0].external}"
}
