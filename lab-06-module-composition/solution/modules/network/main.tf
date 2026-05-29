locals {
  effective_labels = merge(
    { managed_by = "terraform", component = "network" },
    var.labels,
  )
}

resource "docker_network" "this" {
  name   = var.name
  driver = "bridge"

  dynamic "labels" {
    for_each = local.effective_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
