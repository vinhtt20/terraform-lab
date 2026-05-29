# tests/basic.tftest.hcl
# Run with: `terraform test` from the `starter/` directory.

variables {
  rotation_id   = "v1"
  external_port = 8241
}

run "initial_apply" {
  command = apply

  assert {
    condition     = output.container_name == "tflab-12-app"
    error_message = "Container name must be 'tflab-12-app'."
  }

  assert {
    condition     = output.url == "http://localhost:8241"
    error_message = "URL must reflect external_port=8241."
  }

  # TODO — once you implement the rotation_marker output, uncomment:
  #
  # assert {
  #   condition     = output.rotation_marker == "v1"
  #   error_message = "rotation_marker must mirror rotation_id."
  # }
}

run "rotation_changes_marker" {
  command = apply

  variables {
    rotation_id   = "v2"
    external_port = 8241
  }

  # TODO — assert rotation_marker is now "v2" after rotating:
  #
  # assert {
  #   condition     = output.rotation_marker == "v2"
  #   error_message = "rotation_marker should follow rotation_id."
  # }
}
