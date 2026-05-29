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

  assert {
    condition     = output.rotation_marker == "v1"
    error_message = "rotation_marker must mirror rotation_id at apply time."
  }
}

run "rotation_changes_marker" {
  command = apply

  variables {
    rotation_id   = "v2"
    external_port = 8241
  }

  assert {
    condition     = output.rotation_marker == "v2"
    error_message = "rotation_marker should follow rotation_id after rotation."
  }

  assert {
    condition     = output.container_name == "tflab-12-app"
    error_message = "Container name should remain stable across rotations."
  }
}
