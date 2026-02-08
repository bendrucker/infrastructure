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

resource "cloudflare_ruleset" "redirects" {
  zone_id     = cloudflare_zone.vanity.id
  name        = "default"
  description = ""
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
            expression = "wildcard_replace(http.request.full_uri, r\"https://${cloudflare_zone.vanity.name}/*\", r\"https://www.${cloudflare_zone.vanity.name}/$${1}\")"
          }
          preserve_query_string = true
        }
      }
    }
  ]
}


resource "cloudflare_dns_record" "things" {
  zone_id = cloudflare_zone.vanity.id
  name    = "things.${cloudflare_zone.vanity.name}"
  type    = "A"
  content = "192.0.2.1"
  ttl     = 1
  proxied = true
}

resource "cloudflare_ruleset" "things" {
  zone_id     = cloudflare_zone.vanity.id
  name        = "things"
  description = ""
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [
    {
      ref         = "things_to_app"
      description = "Redirect things subdomain to Things app URL scheme"
      expression  = "(http.host eq \"${cloudflare_dns_record.things.name}\")"
      action      = "redirect"
      action_parameters = {
        from_value = {
          status_code = 302
          target_url = {
            expression = "concat(\"things://\", http.request.uri)"
          }
          preserve_query_string = false
        }
      }
    }
  ]
}

resource "cloudflare_dns_record" "txt" {
  zone_id = cloudflare_zone.vanity.id
  name    = cloudflare_zone.vanity.name
  type    = "TXT"
  content = "keybase-site-verification=8ic85gbwQMRpqKksDrw_hQdsvg9WEVvX2UBvEiPHhwk"
  ttl     = 1
}

import {
  to = cloudflare_ruleset.redirects
  id = "zones/c783f775892feb7781197c65222d9612/90ba3ffb134642349ffbef9787f23834"
}
