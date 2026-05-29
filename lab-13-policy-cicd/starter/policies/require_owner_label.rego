# Policy: require every docker_container to carry a label `owner` with a
# non-empty value.
#
# Docker provider stores labels as a LIST of objects:
#
#   "labels": [
#     { "label": "owner",     "value": "platform-team" },
#     { "label": "tflab.lab", "value": "13" }
#   ]
#
# Build a set of label-names first, then check whether "owner" is in it.

package main

# TODO — fill in a `deny` rule that:
#
# 1. Iterates over docker_container resources.
# 2. Builds a set of label names (or uses a comprehension to extract them).
# 3. Denies if "owner" is NOT in that set.
#
# Useful Rego helpers:
#
#   labels_set := { entry.label | entry := resource.values.labels[_] }
#
#   not labels_set["owner"]
#
# Example skeleton:
#
# deny[msg] {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "docker_container"
#     labels := { entry.label | entry := resource.values.labels[_] }
#     not labels["owner"]
#     msg := sprintf("docker_container %q missing required label 'owner'.",
#                    [resource.address])
# }
