resource "cloudflare_zone" "vanity" {
  account = {
    id = var.cloudflare_account_id
  }

  name = "bendrucker.me"
}

resource "cloudflare_dns_record" "apex" {
  zone_id = cloudflare_zone.vanity.id
  name    = cloudflare_zone.vanity.name
  type    = "A"
  content = "192.0.2.1" # RFC 5737 TEST-NET-1 placeholder IP, actual traffic handled by Cloudflare proxy
  ttl     = 1
  proxied = true
}

resource "cloudflare_ruleset" "apex_www" {
  zone_id     = cloudflare_zone.vanity.id
  name        = "redirects"
  description = "Single redirects ruleset"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [
    {
      ref         = "apex_to_www"
      description = "Redirect apex domain to www"
      expression  = "(http.request.full_uri wildcard r\"https://${cloudflare_zone.vanity.name}/*\")"
      action      = "redirect"
      action_parameters = {
        from_value = {
          status_code = 301
          target_url = {
            expression = "wildcard_replace(http.request.full_uri, r\"https://${cloudflare_zone.vanity.name}/*\", r\"https://${cloudflare_dns_record.github.name}/$${1}\")"
          }
          preserve_query_string = false
        }
      }
    }
  ]
}

resource "cloudflare_dns_record" "github" {
  zone_id = cloudflare_zone.vanity.id
  name    = "www.${cloudflare_zone.vanity.name}"
  type    = "CNAME"
  content = "bendrucker.github.io"
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "txt" {
  zone_id = cloudflare_zone.vanity.id
  name    = cloudflare_zone.vanity.name
  type    = "TXT"
  content = "keybase-site-verification=8ic85gbwQMRpqKksDrw_hQdsvg9WEVvX2UBvEiPHhwk"
  ttl     = 1
}

import {
  to = cloudflare_dns_record.github
  id = "c783f775892feb7781197c65222d9612/b92197317815aba695b8ed8aa7ab2efb"
}

import {
  to = cloudflare_dns_record.txt
  id = "c783f775892feb7781197c65222d9612/29a2a1352dc3c1fe707beae9a9c164cd"
}
