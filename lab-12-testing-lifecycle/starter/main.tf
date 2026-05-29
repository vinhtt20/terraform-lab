# ----------------------------------------------------------------------------
# LAB 12 — TESTING & LIFECYCLE (replace_triggered_by, terraform_data, ephemeral)
#
# Two ideas working together:
#
#   1. `terraform_data` (TF 1.4+) — a managed no-op resource. Its `input` is
#      stored in `output` (and `triggers_replace` if you want). Use it as a
#      sentinel: a stable address whose lifecycle you can attach external
#      signals to.
#
#   2. `replace_triggered_by` (TF 1.2+) — lifecycle directive that forces a
#      resource to be REPLACED when any tracked resource/attribute changes.
#
#   Together: change `rotation_id` → terraform_data.rotation changes →
#   container replaced. Useful for credential rotation, certificate rollouts,
#   cache busting, etc.
#
# Plus we will exercise `terraform test` (TF 1.6+) — native testing framework
# that runs apply against the module and asserts outputs/state. See
# `tests/basic.tftest.hcl`.
#
# Ephemeral output demo lives in outputs.tf (TF 1.10+).
# ----------------------------------------------------------------------------

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# TODO — declare a `terraform_data` resource named "rotation":
#   - `input = var.rotation_id`
#   - This resource's `output` will mirror the input. It produces no infra,
#     but `replace_triggered_by` in the container below will watch it.
#
# resource "terraform_data" "rotation" {
#   input = var.rotation_id
# }

resource "docker_container" "app" {
  name  = "tflab-12-app"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    # TODO — add `replace_triggered_by` that watches `terraform_data.rotation`.
    # When that resource's `output` changes (because we changed rotation_id),
    # Terraform will REPLACE this container.
    #
    # replace_triggered_by = [terraform_data.rotation]

    ignore_changes = [log_opts]
  }
}
