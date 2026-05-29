module "web" {
  for_each = var.services
  source   = "./modules/web_service"

  name      = each.key
  port      = each.value.port
  owner     = each.value.owner
  image_tag = each.value.image_tag
}

check "service_count_within_bounds" {
  assert {
    condition     = length(var.services) <= 5
    error_message = "Capstone supports up to 5 concurrent services."
  }
}
