# A short random suffix used only as a "build id" stamped into the rendered
# HTML — proof that the module receives caller-computed values cleanly.
resource "random_id" "build" {
  byte_length = 4
}

# Call #1 — the API service. Minimal configuration: no custom index, no logs.
# Demonstrates the "happy path" of using the module with mostly defaults.
module "api" {
  source = "./modules/web_service"

  name          = "api"
  image         = var.image
  external_port = 8093

  labels = {
    role = "backend"
    tier = "api"
  }
}

# Call #2 — the frontend service. Demonstrates passing computed values
# (`templatefile()` output) and toggling the optional log volume.
module "frontend" {
  source = "./modules/web_service"

  name              = "frontend"
  image             = var.image
  external_port     = 8094
  enable_log_volume = true

  index_content = templatefile("${path.module}/templates/frontend.html.tftpl", {
    title    = "tflab-05 Frontend"
    build_id = random_id.build.hex
  })

  labels = {
    role = "frontend"
    tier = "web"
  }
}
