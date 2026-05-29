locals {
  # Prefix used for every container's name. Centralizing avoids drift between
  # main.tf (container names) and outputs.tf (display).
  container_name_prefix = "tflab-02-${var.service_name}"

  # Always add managed_by=terraform so a human inspecting Docker can see who owns this.
  merged_labels = merge(var.labels, { managed_by = "terraform" })

  # "Use the value the caller provided, OR fall back to the generated random_password".
  # try(...) handles the case where count=0 so random_password.admin[0] does not exist.
  password_effective = coalesce(
    var.admin_password,
    try(random_password.admin[0].result, null)
  )
}
