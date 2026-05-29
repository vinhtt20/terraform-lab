# Capstone smoke test: deploy 2 services, assert URLs and container names.

run "smoke" {
  command = apply

  variables {
    services = {
      api = {
        port  = 8281
        owner = "platform-team"
      }
      web = {
        port  = 8282
        owner = "frontend-team"
      }
    }
  }

  # TODO — once outputs are implemented, uncomment these assertions:
  #
  # assert {
  #   condition     = output.service_urls["api"] == "http://localhost:8281"
  #   error_message = "api URL mismatch."
  # }
  #
  # assert {
  #   condition     = output.service_containers["web"] == "tflab-14-web"
  #   error_message = "web container name mismatch."
  # }
}

# Negative test: duplicate ports must fail validation at plan-time.
run "reject_duplicate_ports" {
  command = plan

  variables {
    services = {
      svc1 = { port = 8285, owner = "team-a" }
      svc2 = { port = 8285, owner = "team-b" } # duplicate port
    }
  }

  expect_failures = [var.services]
}
