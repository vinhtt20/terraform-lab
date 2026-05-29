# =====================================================================
# Lab 07 — SOLUTION: import legacy container + volume into Terraform state.
#
# These resource blocks describe Docker resources that *already exist* —
# they were created out-of-band with `docker run` / `docker volume create`
# in setup.sh. The classic workflow is:
#
#   1. Write the resource block by hand (this file).
#   2. `terraform import <addr> <id>` to attach the existing object to state.
#   3. `terraform plan` — read the diff carefully; refine the block until
#      Terraform reports "No changes" (zero diff between config and state).
#
# Reaching zero-diff means the config now FAITHFULLY represents the live
# resource. Apply is then a no-op refresh; no recreation, no downtime.
# =====================================================================

# The image is *not* imported. Docker pulls are idempotent and don't carry
# the kind of mutable state that needs reconciliation. Declaring it normally
# lets Terraform pull it if missing and otherwise leave it alone.
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# Imported pre-existing volume. Name is the import ID (Docker volumes are
# identified by name, not by an opaque id).
resource "docker_volume" "legacy_data" {
  name = "tflab-07-legacy-data"
}

# Imported pre-existing container. Every attribute below was tuned to match
# what `docker inspect tflab-07-legacy-app` actually reports — that's how we
# reach zero-diff after import. Common gotchas (and why each one is here):
#
#  - `must_run = true` : the container is running; default would also be true
#    but we set it explicitly to make the intent visible in diff output.
#  - `restart = "unless-stopped"` : matches `--restart unless-stopped` passed
#    to `docker run`. Default ("no") would diff every plan.
#  - `network_mode = "bridge"` : Docker assigns the default bridge network to
#    containers started without `--network`; the provider would otherwise
#    show this as a diff.
#  - `log_driver = "json-file"` : Docker default. Provider reads it from the
#    live container and would diff if we omitted it.
resource "docker_container" "legacy_app" {
  name  = "tflab-07-legacy-app"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8110
  }

  volumes {
    volume_name    = docker_volume.legacy_data.name
    container_path = "/var/data"
  }

  restart      = "unless-stopped"
  must_run     = true
  network_mode = "bridge"
  log_driver   = "json-file"

  # `log_opts` is populated from the Docker daemon's default LogConfig on the
  # host (`docker info` → "Default Logging Driver"). It varies by machine and
  # is not something we want to manage in Terraform — silence diffs on it.
  # This is the *one* legitimate use of ignore_changes for this lab: an
  # attribute the live host owns, not our config. See README "Đào sâu".
  lifecycle {
    ignore_changes = [log_opts]
  }
}
