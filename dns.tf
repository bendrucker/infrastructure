resource "cloudflare_zone" "vanity" {
  account = {
    id = var.cloudflare_account_id
  }

  name = "bendrucker.me"
}

resource "cloudflare_dns_record" "wwwizer" {
  zone_id = cloudflare_zone.vanity.id
  name    = cloudflare_zone.vanity.name
  type    = "A"
  content = "174.129.25.170"
  ttl     = 1
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

removed {
  from = cloudflare_record.wwwizer

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_record.github

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_record.txt

  lifecycle {
    destroy = false
  }
}

import {
  to = cloudflare_dns_record.wwwizer
  id = "c783f775892feb7781197c65222d9612/a132e35e44ae39deabc7905eb9778248"
}

import {
  to = cloudflare_dns_record.github
  id = "c783f775892feb7781197c65222d9612/b92197317815aba695b8ed8aa7ab2efb"
}

import {
  to = cloudflare_dns_record.txt
  id = "c783f775892feb7781197c65222d9612/29a2a1352dc3c1fe707beae9a9c164cd"
}
