resource "cloudflare_dns_record" "hub" {
  zone_id = cloudflare_zone.vanity.id
  name    = "hub.${cloudflare_zone.vanity.name}"
  type    = "A"
  content = "192.0.2.1"
  ttl     = 1
  proxied = true
}

# The script itself is deployed by wrangler from the activity-hub repo. Only
# the hostname and the route belong here.
resource "cloudflare_workers_route" "hub" {
  zone_id = cloudflare_zone.vanity.id
  pattern = "${cloudflare_dns_record.hub.name}/*"
  script  = "activity-hub-ingest"
}

resource "cloudflare_zero_trust_access_policy" "hub_owner" {
  account_id = var.cloudflare_account_id
  name       = "activity-hub owner"
  decision   = "allow"

  include = [{
    email = {
      email = "bvdrucker@gmail.com"
    }
  }]
}

resource "cloudflare_zero_trust_access_service_token" "hub" {
  account_id = var.cloudflare_account_id
  name       = "activity-hub automation"
}

# Service tokens carry no identity, so they need a policy that asks for none.
resource "cloudflare_zero_trust_access_policy" "hub_automation" {
  account_id = var.cloudflare_account_id
  name       = "activity-hub automation"
  decision   = "non_identity"

  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.hub.id
    }
  }]
}

# Access matches on hostname and path prefix, so /webhooks stays reachable by
# being covered by no application at all. Strava and Wahoo post to it server to
# server and would fail any challenge.
resource "cloudflare_zero_trust_access_application" "hub_admin" {
  account_id       = var.cloudflare_account_id
  name             = "activity-hub admin"
  domain           = "${cloudflare_dns_record.hub.name}/admin"
  type             = "self_hosted"
  session_duration = "24h"

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.hub_owner.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.hub_automation.id
      precedence = 2
    },
  ]
}

# The OAuth callbacks land here as browser navigations, so the owner policy
# alone covers them. Nothing automated hits /auth.
resource "cloudflare_zero_trust_access_application" "hub_auth" {
  account_id       = var.cloudflare_account_id
  name             = "activity-hub auth"
  domain           = "${cloudflare_dns_record.hub.name}/auth"
  type             = "self_hosted"
  session_duration = "24h"

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.hub_owner.id
      precedence = 1
    },
  ]
}

output "activity_hub_access_client_id" {
  description = "CF-Access-Client-Id header value for activity-hub scripts"
  value       = cloudflare_zero_trust_access_service_token.hub.client_id
}

output "activity_hub_access_client_secret" {
  description = "CF-Access-Client-Secret header value for activity-hub scripts"
  value       = cloudflare_zero_trust_access_service_token.hub.client_secret
  sensitive   = true
}
