# Capstone policy: every docker_container managed by Terraform must carry an
# `owner` label. Reuses the Rego pattern from Lab 13.
#
# Plan JSON for child_modules: resources are NESTED under
# `input.planned_values.root_module.child_modules[_].resources[_]`.
# Make sure the rule walks both root + child resources, OR write 2 rules.

package main

# TODO — write a deny rule that:
# 1. Iterates `child_modules[_].resources[_]` (since we use a module).
# 2. Filters resource.type == "docker_container".
# 3. Builds labels set and denies if "owner" missing.
#
# deny[msg] {
#     resource := input.planned_values.root_module.child_modules[_].resources[_]
#     resource.type == "docker_container"
#     labels := { entry.label | entry := resource.values.labels[_] }
#     not labels["owner"]
#     msg := sprintf("docker_container %q missing required label 'owner'.",
#                    [resource.address])
# }
