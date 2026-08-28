resource "cloudflare_zone" "vanity" {
  account = {
    id = var.cloudflare_account_id
  }

  name = "bendrucker.me"
}

# The apex record and the apex-to-www redirect belong to the website, so
# bendrucker/bendrucker.me adopts them in its own infra root with import blocks.
# Dropping them from state here leaves both Cloudflare objects untouched. The
# zone stays: it is shared substrate for the records below and for activity-hub.
#
# Order matters. This has to apply before the website repo's import lands, or
# two states claim the same objects.

# The ids the website repo's import blocks have to carry. They are recorded
# here because deleting the resource blocks also deletes the only copy of them
# in this repo: the apex record's id lived nowhere but state, and the ruleset's
# lived in the import block this change removes. A wrong id there does not
# fail loudly, it adopts some other object.
removed {
  from = cloudflare_dns_record.apex # c783f775892feb7781197c65222d9612/b1934803c9c663dbdad730c66c041be3

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_ruleset.redirects # zones/c783f775892feb7781197c65222d9612/90ba3ffb134642349ffbef9787f23834

  lifecycle {
    destroy = false
  }
}

resource "cloudflare_dns_record" "things" {
  zone_id = cloudflare_zone.vanity.id
  name    = "things.${cloudflare_zone.vanity.name}"
  type    = "A"
  content = "192.0.2.1"
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
