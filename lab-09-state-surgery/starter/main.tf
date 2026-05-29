# ----------------------------------------------------------------------------
# LAB 09 — STATE SURGERY
#
# This is the "legacy" config: three separate container resources with ad-hoc
# names. The Docker objects already exist (after the FIRST apply); your job is
# to REFACTOR THE STATE in place — without recreating any container.
#
# ----------------------------------------------------------------------------
# STEP 0 — BOOTSTRAP (run once, before refactoring):
#   cd starter
#   terraform init
#   terraform apply       # creates web1, web2, web3 live + state
#   terraform state list  # confirm 4 entries (image + 3 containers)
#
# After step 0 you SHOULD see in state:
#   docker_image.nginx
#   docker_container.web1
#   docker_container.web2
#   docker_container.web3
#
# ----------------------------------------------------------------------------
# STEP 1 — REFACTOR (this is the assignment):
#
#   Goal A: gộp web1 + web2 thành ONE resource `docker_container.web` với
#           `for_each = local.apps`. Container LIVE không được recreate
#           (zero-downtime state-only refactor).
#   Goal B: deprecate web3 — xoá khỏi state nhưng KHÔNG destroy container
#           Docker. Lý do business: team khác sẽ take over web3.
#
# Use DECLARATIVE blocks (preferred over `terraform state` CLI):
#
#   moved {                          # for Goal A — one block per address change
#     from = docker_container.web1
#     to   = docker_container.web[...]
#   }
#
#   removed {                        # for Goal B — declarative state rm
#     from = docker_container.web3
#     lifecycle { destroy = false }  # keep live container, only forget it
#   }
#
# IMPORTANT — for `moved {}` to be a pure state migration, the resulting
# container `name` must equal the legacy one (`tflab-09-web1`). If you change
# the name (e.g. to `tflab-09-app1`) Terraform will force-replace the container
# and destroy it — defeating the refactor. Choose your `local.apps` keys so
# that `"tflab-09-${each.key}"` reproduces the existing names.
#
# After refactor `terraform plan` must report:
#   Plan: 0 to add, 0 to change, 0 to destroy.
#
# ----------------------------------------------------------------------------

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web1" {
  name  = "tflab-09-web1"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8191
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}

resource "docker_container" "web2" {
  name  = "tflab-09-web2"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8192
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}

resource "docker_container" "web3" {
  name  = "tflab-09-web3"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8193
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}

# ----------------------------------------------------------------------------
# TODO STEP 2 — replace web1 + web2 with the for_each form below
# (uncomment & remove the originals), and add the `moved {}` blocks.
# For web3, REMOVE its resource block entirely and add a `removed {}` block.
# ----------------------------------------------------------------------------
#
# locals {
#   apps = {
#     web1 = { port = 8191 }   # key MUST be "web1"/"web2" to keep container name
#     web2 = { port = 8192 }
#   }
# }
#
# resource "docker_container" "web" {
#   for_each = local.apps
#
#   name  = "tflab-09-${each.key}"
#   image = docker_image.nginx.image_id
#
#   ports {
#     internal = 80
#     external = each.value.port
#   }
#
#   restart  = "unless-stopped"
#   must_run = true
#
#   lifecycle {
#     ignore_changes = [log_opts]
#   }
# }
#
# moved {
#   from = docker_container.web1
#   to   = docker_container.web["web1"]
# }
#
# moved {
#   from = docker_container.web2
#   to   = docker_container.web["web2"]
# }
#
# removed {
#   from = docker_container.web3
#   lifecycle {
#     destroy = false
#   }
# }
