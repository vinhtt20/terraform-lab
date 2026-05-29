locals {
  # Source of truth for every service in the platform. Adding a new service is
  # a 1-line change here — neither module needs to be edited.
  services = {
    web = {
      region        = "east"
      image         = "nginx:1.27-alpine"
      external_port = 8100
      replicas      = 2
    }
    api = {
      region        = "west"
      image         = "nginx:1.27-alpine"
      external_port = 8102
      replicas      = 1
    }
    worker = {
      region        = "east"
      image         = "nginx:1.27-alpine"
      external_port = 8103
      replicas      = 1
    }
  }

  # Partition the services map by region. Why?
  # `for_each` on `module` is supported, but `providers = { docker.target = ... }`
  # is STATIC per module call — it cannot vary by each.value.region. The
  # canonical workaround is one module call per region. See README "Đào sâu".
  services_east = { for k, v in local.services : k => v if v.region == "east" }
  services_west = { for k, v in local.services : k => v if v.region == "west" }
}

# Network module — region-agnostic, uses the default `docker` provider.
module "network" {
  source = "./modules/network"

  name = "tflab-06-net"
  labels = {
    env = "dev"
  }
}

# Eastern services — for_each over the eastern subset. The `docker.east`
# provider is passed in via the `providers` map; every resource in the module
# that says `provider = docker.target` will use `docker.east`.
module "service_east" {
  source   = "./modules/service"
  for_each = local.services_east

  providers = {
    docker.target = docker.east
  }

  name          = each.key
  image         = each.value.image
  external_port = each.value.external_port
  network_name  = module.network.name
  replicas      = each.value.replicas

  labels = {
    region = "east"
    role   = each.key
  }
}

# Western services — same shape, different provider alias.
module "service_west" {
  source   = "./modules/service"
  for_each = local.services_west

  providers = {
    docker.target = docker.west
  }

  name          = each.key
  image         = each.value.image
  external_port = each.value.external_port
  network_name  = module.network.name
  replicas      = each.value.replicas

  labels = {
    region = "west"
    role   = each.key
  }
}
