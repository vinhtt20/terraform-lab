# ----------------------------------------------------------------------------
# LAB 11 — VALIDATION & CUSTOM CONDITIONS
#
# Three layers of safety nets:
#
#   1. variable `validation {}` — checks INPUT VALUES at parse time.
#                                 Cheap, runs even before plan.
#   2. resource `lifecycle.precondition {}`  — checks before resource action.
#      resource `lifecycle.postcondition {}` — checks after action completes.
#                                 Both can reference attribute values.
#   3. top-level `check {}` block — best-effort assertions; emit warnings
#                                   rather than failing apply. Good for SLOs
#                                   and invariants spanning many resources.
#
# After this lab you should be able to tell at a glance which mechanism fits
# which failure mode.
# ----------------------------------------------------------------------------

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true

  # TODO — add a postcondition that ensures `self.image_id` is non-empty.
  # Hint:
  # lifecycle {
  #   postcondition {
  #     condition     = self.image_id != ""
  #     error_message = "..."
  #   }
  # }
}

resource "docker_container" "app" {
  count = var.replicas

  name  = "${var.name_prefix}-${count.index + 1}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.base_port + count.index
  }

  restart  = "unless-stopped"
  must_run = true

  # TODO — wrap the existing `lifecycle { ignore_changes = [log_opts] }` and
  # ADD two custom conditions:
  #
  #   precondition {
  #     condition     = (var.base_port + count.index) < 10000
  #     error_message = "Port (base_port + count.index) exceeds 9999."
  #   }
  #
  #   postcondition {
  #     condition     = length(self.ports) > 0 && self.ports[0].external == (var.base_port + count.index)
  #     error_message = "Container did not expose the expected external port."
  #   }
  lifecycle {
    ignore_changes = [log_opts]
  }
}

# TODO — add a top-level `check {}` block named "unique_ports" that asserts
# every container has a unique external port. Use this expression:
#
#   length(distinct([for c in docker_container.app : c.ports[0].external])) == length(docker_container.app)
#
# check "unique_ports" {
#   assert {
#     condition     = ...
#     error_message = "External ports of containers must be unique."
#   }
# }
