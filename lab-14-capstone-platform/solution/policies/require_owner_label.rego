package main

# Capstone: every docker_container under any child_module must have an
# `owner` label.
deny[msg] {
	resource := input.planned_values.root_module.child_modules[_].resources[_]
	resource.type == "docker_container"
	labels := {entry.label | entry := resource.values.labels[_]}
	not labels["owner"]
	msg := sprintf("docker_container %q missing required label 'owner'.", [resource.address])
}

# Also check root-level resources (defense in depth).
deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "docker_container"
	labels := {entry.label | entry := resource.values.labels[_]}
	not labels["owner"]
	msg := sprintf("docker_container %q missing required label 'owner'.", [resource.address])
}
