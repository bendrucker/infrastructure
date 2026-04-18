resource "cloudflare_workers_script" "things_redirect" {
  account_id         = var.cloudflare_account_id
  script_name        = "things-redirect"
  main_module        = "worker.js"
  content            = file("workers/things-redirect/worker.js")
  compatibility_date = "2026-03-06"

  bindings = [{
    name = "HTML"
    type = "plain_text"
    text = file("workers/things-redirect/index.html")
  }]
}

resource "cloudflare_workers_route" "things" {
  zone_id = cloudflare_zone.vanity.id
  pattern = "${cloudflare_dns_record.things.name}/*"
  script  = cloudflare_workers_script.things_redirect.script_name
}
