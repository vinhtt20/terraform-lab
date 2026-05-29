# ----------------------------------------------------------------------------
# LAB 10 — BACKENDS, WORKSPACES, DRIFT
#
# Goal: deploy ONE config to TWO environments (dev, prod) using Terraform
# workspaces, with state stored in separate files via the local backend. Then
# practise drift detection and `-refresh-only`.
#
# Steps you will perform manually (the verify script grades final state):
#   cd starter
#   terraform init
#
#   terraform workspace new dev          # creates terraform.tfstate.d/dev/
#   terraform apply                      # → tflab-10-dev-1 on :8201
#
#   terraform workspace new prod         # creates terraform.tfstate.d/prod/
#   terraform apply                      # → tflab-10-prod-1 on :8202
#                                        #   tflab-10-prod-2 on :8203
#
#   terraform workspace list             # default, dev, prod*
#
# Then exercises:
#   (A) drift detection:
#       docker stop tflab-10-dev-1
#       terraform workspace select dev && terraform plan    # diff!
#       terraform apply                                     # remediates
#
#   (B) -refresh-only (state sync without infra change):
#       see README "Đào sâu" for a meaningful refresh-only scenario.
#
# ----------------------------------------------------------------------------

locals {
  # `terraform.workspace` resolves to "default" / "dev" / "prod" depending on
  # the current workspace. Use `lookup` with the "default" key as fallback.
  cfg = lookup(var.workspace_config, terraform.workspace, var.workspace_config["default"])
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# TODO — declare the container resource with the following requirements:
#
#   1. `count` driven by `local.cfg.replicas`.
#   2. Container `name` must include the workspace name and the replica index,
#      e.g. "tflab-10-dev-1", "tflab-10-prod-1", "tflab-10-prod-2".
#   3. External port = `local.cfg.port + count.index`
#      (prod with replicas=2 thus exposes 8202 and 8203).
#   4. Add a label so live `docker inspect` shows which workspace owns it:
#        labels { label = "tflab.workspace"; value = terraform.workspace }
#   5. restart = "unless-stopped", must_run = true.
#   6. ignore_changes = [log_opts]  (Docker daemon fills these in).
#
# resource "docker_container" "app" {
#   count = local.cfg.replicas
#   ...
# }
