locals {
  domain = "bendrucker.me"
}

resource "cloudflare_zone" "vanity" {
  zone = local.domain
}

resource "cloudflare_record" "wwwizer" {
  domain = local.domain
  name   = "bendrucker.me"
  type   = "A"
  value  = "174.129.25.170"
  ttl    = "1"
}

resource "cloudflare_record" "github" {
  domain  = local.domain
  name    = "www"
  type    = "CNAME"
  value   = "bendrucker.github.io"
  ttl     = "1"
  proxied = true
}
