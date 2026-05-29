package main

# Require every docker_container to declare a label "owner".
deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "docker_container"
	labels := {entry.label | entry := resource.values.labels[_]}
	not labels["owner"]
	msg := sprintf("docker_container %q missing required label 'owner'.", [resource.address])
}
