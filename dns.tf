resource "cloudflare_zone" "vanity" {
  zone = "bendrucker.me"
}

resource "cloudflare_record" "wwwizer" {
  zone_id = cloudflare_zone.vanity.id
  name   = cloudflare_zone.vanity.zone
  type   = "A"
  value  = "174.129.25.170"
  ttl    = "1"
}

resource "cloudflare_record" "github" {
  zone_id = cloudflare_zone.vanity.id
  name    = "www"
  type    = "CNAME"
  value   = "bendrucker.github.io"
  ttl     = "1"
  proxied = true
}

resource "cloudflare_record" "txt" {
  zone_id = cloudflare_zone.vanity.id
  name   = cloudflare_zone.vanity.zone
  type   = "TXT"
  value = join("\n", [
    "keybase-site-verification=8ic85gbwQMRpqKksDrw_hQdsvg9WEVvX2UBvEiPHhwk"
  ])
  ttl = "1"
}
