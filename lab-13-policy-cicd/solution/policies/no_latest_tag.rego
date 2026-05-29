package main

# Deny when docker_image uses ":latest" tag.
deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "docker_image"
	endswith(resource.values.name, ":latest")
	msg := sprintf("docker_image %q uses :latest tag — forbidden by policy.", [resource.address])
}

# Deny when docker_image has no explicit tag (Docker defaults to :latest).
deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "docker_image"
	not contains(resource.values.name, ":")
	msg := sprintf("docker_image %q has no explicit tag — must pin a version.", [resource.address])
}
