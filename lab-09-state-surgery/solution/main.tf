# Refactored config — two containers under a single for_each resource;
# web3 has been deprecated out of state without destroying the live container.
#
# CRITICAL: container `name` is preserved across the refactor
# ("tflab-09-web1" stays "tflab-09-web1") so `moved {}` performs a pure
# state migration. Changing the name would force-replace the container —
# defeating the whole point of declarative state surgery.
#
# Migration is performed declaratively with `moved {}` and `removed {}` blocks,
# making the refactor visible in code review and reversible by `git revert`.

locals {
  # Keys match the legacy resource suffix so `name = "tflab-09-${each.key}"`
  # reproduces the original container names verbatim.
  apps = {
    web1 = { port = 8191 }
    web2 = { port = 8192 }
  }
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  for_each = local.apps

  name  = "tflab-09-${each.key}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = each.value.port
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}

# State migrations — visible in PR review, plannable, idempotent.
# After the first apply that processes these, the blocks can be deleted
# (one or two release cycles later) once everyone has rebased past them.

moved {
  from = docker_container.web1
  to   = docker_container.web["web1"]
}

moved {
  from = docker_container.web2
  to   = docker_container.web["web2"]
}

# Declarative `terraform state rm` — keep the live container, forget the address.
# Use case: another team is taking over web3; we no longer want Terraform to
# manage it but the container must keep serving traffic.
removed {
  from = docker_container.web3

  lifecycle {
    destroy = false
  }
}
