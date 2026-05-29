# ----------------------------------------------------------------------------
# LAB 14 — CAPSTONE: mini-platform
#
# Compose the `web_service` module with `for_each` over `var.services`. Each
# entry becomes one container. The module enforces validation, postcondition,
# and emits an ephemeral `deploy_token`.
#
# This root module adds a `check {}` block to assert global invariants.
# ----------------------------------------------------------------------------

# TODO — instantiate the module with for_each over var.services. Pass `name`,
# `port`, `owner`, `image_tag` from each map entry.
#
# module "web" {
#   for_each = var.services
#   source   = "./modules/web_service"
#
#   name      = each.key
#   port      = each.value.port
#   owner     = each.value.owner
#   image_tag = each.value.image_tag
# }

# TODO — add a top-level check {} block asserting an invariant.
#
# check "service_count_within_bounds" {
#   assert {
#     condition     = length(var.services) <= 5
#     error_message = "Capstone supports up to 5 concurrent services."
#   }
# }
