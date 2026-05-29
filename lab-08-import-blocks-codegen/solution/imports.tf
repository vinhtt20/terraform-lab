# =====================================================================
# Lab 08 — SOLUTION: `import {}` blocks for the legacy stack.
#
# In Terraform 1.5+, `import {}` is the declarative replacement for the
# classic `terraform import` CLI. Each block says "the live object with
# this ID should be associated with this Terraform address on the next
# apply". Benefits:
#
#   - Plannable: shows up in `terraform plan` BEFORE state mutation.
#   - Reviewable: lives in source, can be peer-reviewed in a PR.
#   - Bulk: many imports in one apply.
#   - Codegen: `terraform plan -generate-config-out=out.tf` emits draft
#     resource blocks (which we then refactor — see main.tf).
#
# The `id` argument can be any expression that's known at plan time.
# Names work for volumes & networks (the provider accepts them as IDs).
# Container IDs are NOT predictable, so we fetch them with a tiny
# `external` data source that calls `docker inspect`. This is more
# idiomatic than asking a human to hand-paste 3 sha hashes.
#
# After a successful apply, you can either DELETE this file (the state
# entry persists) or KEEP it as an audit trail of what was imported.
# Team policy decision — both are valid. See README "Đào sâu".
# =====================================================================

# Look up the live container IDs via Docker CLI. The external data
# source contract: program prints a single JSON object whose values are
# all strings; we read those into `.result.<key>`.
data "external" "container_ids" {
  program = ["bash", "-c", <<-EOT
    jq -n \
      --arg app1 "$(docker inspect --format '{{.Id}}' tflab-08-app1)" \
      --arg app2 "$(docker inspect --format '{{.Id}}' tflab-08-app2)" \
      --arg app3 "$(docker inspect --format '{{.Id}}' tflab-08-app3)" \
      '{app1: $app1, app2: $app2, app3: $app3}'
  EOT
  ]
}

import {
  to = docker_network.main
  id = "tflab-08-net"
}

import {
  for_each = local.volumes
  to       = docker_volume.this[each.key]
  id       = "tflab-08-${each.key}"
}

import {
  for_each = local.apps
  to       = docker_container.app[each.key]
  id       = data.external.container_ids.result[each.key]
}
