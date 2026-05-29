# Policy: forbid docker_image resources from using :latest tag (or no tag).
#
# Conftest expects each .rego file to declare `package main` (or another
# package, selectable with --namespace). A rule named `deny` emits a
# violation; `warn` emits a warning. Each msg in the rule's iteration
# produces one finding.
#
# The input document for Conftest when fed a Terraform plan JSON looks like:
#
#   input.planned_values.root_module.resources[i] = {
#     "address": "docker_image.app",
#     "type":    "docker_image",
#     "name":    "app",
#     "values":  { "name": "nginx:1.27-alpine", ... },
#     ...
#   }
#
# So a policy rule typically iterates over `input.planned_values.root_module.resources[_]`
# and checks the `values` field.

package main

# TODO — fill in two `deny` rules:
#
# 1. Forbid docker_image resources whose `values.name` ends with ":latest".
#    Use `endswith(string, suffix)` (Rego builtin).
#
# 2. Forbid docker_image resources whose `values.name` contains NO ":" at all
#    (untagged → Docker treats as :latest). Use `contains(string, substring)`
#    and `not` operator.
#
# Each `deny` rule should build `msg := sprintf(...)` mentioning the
# resource address so users know which line to fix.
#
# Skeleton:
#
# deny[msg] {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "docker_image"
#     endswith(resource.values.name, ":latest")
#     msg := sprintf("docker_image %q uses :latest tag — forbidden by policy.",
#                    [resource.address])
# }
