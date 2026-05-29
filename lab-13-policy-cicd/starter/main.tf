# ----------------------------------------------------------------------------
# LAB 13 — POLICY AS CODE + CI/CD GATING
#
# Workflow you will build:
#
#   terraform plan -out=tfplan
#   terraform show -json tfplan > plan.json
#   conftest test plan.json --policy policies/
#
# `conftest` runs Open Policy Agent (OPA) Rego policies against the plan JSON.
# A policy that emits a `deny` rule blocks the apply (in CI: non-zero exit).
#
# The Terraform config below is COMPLIANT with both starter policies. Your
# job is to (a) write the Rego logic in policies/*.rego, then (b) try
# breaking compliance and observe conftest reject the plan.
# ----------------------------------------------------------------------------

resource "docker_image" "app" {
  # Explicit tag — never use `:latest` in production. The Rego policy
  # `no_latest_tag.rego` will deny resources using :latest or no tag.
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "tflab-13-${var.owner}"
  image = docker_image.app.image_id

  ports {
    internal = 80
    external = var.external_port
  }

  # Required by `require_owner_label.rego`: every container must declare an
  # `owner` label so downstream cost-attribution and on-call routing work.
  labels {
    label = "owner"
    value = var.owner
  }

  labels {
    label = "tflab.lab"
    value = "13"
  }

  restart  = "unless-stopped"
  must_run = true

  lifecycle {
    ignore_changes = [log_opts]
  }
}
