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

# Cloudflare bindings do not cross into a container, so the activity-hub decode
# container reaches R2 over the S3 API instead. An R2 token carries one
# permission level across every bucket it covers, which is why reading raw and
# writing lake are two tokens rather than one.

data "cloudflare_account_api_token_permission_groups_list" "account" {
  account_id = var.cloudflare_account_id
}

locals {
  # one() fails the apply on an ambiguous match instead of picking a group at
  # random, which would mint a token with the wrong permission.
  r2_bucket_read = one([
    for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
    group.id if group.name == "Workers R2 Storage Bucket Item Read"
  ])

  r2_bucket_write = one([
    for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
    group.id if group.name == "Workers R2 Storage Bucket Item Write"
  ])

  # Buckets created outside a jurisdiction take `default` in the resource key.
  r2_bucket_resource_prefix = "com.cloudflare.edge.r2.bucket.${var.cloudflare_account_id}_default_"

  # Wrangler touches a different Cloudflare API for each binding activity-hub
  # declares, so a token that covers deploys but not D1 fails halfway through a
  # migration. The list mirrors the bindings in wrangler.jsonc.
  automation_permission_group_names = [
    "Workers Scripts Write",
    "Workers KV Storage Write",
    "Workers R2 Storage Write",
    "Workers Tail Read",
    "D1 Write",
    "Queues Write",
    "Workers Containers Write",
    "Workers R2 Data Catalog Write",
    "Account Settings Read",
  ]

  automation_permission_groups = [
    for name in local.automation_permission_group_names : {
      id = one([
        for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
        group.id if group.name == name
      ])
    }
  ]
}

resource "cloudflare_account_token" "hub_r2_raw" {
  account_id = var.cloudflare_account_id
  name       = "activity-hub raw read"
  expires_on = "2027-08-12T00:00:00Z"

  policies = [{
    effect = "allow"

    permission_groups = [{
      id = local.r2_bucket_read
    }]

    resources = jsonencode({
      "${local.r2_bucket_resource_prefix}activity-hub-raw" = "*"
    })
  }]
}

resource "cloudflare_account_token" "hub_r2_lake" {
  account_id = var.cloudflare_account_id
  name       = "activity-hub lake write"
  expires_on = "2027-08-12T00:00:00Z"

  policies = [{
    effect = "allow"

    permission_groups = [{
      id = local.r2_bucket_write
    }]

    resources = jsonencode({
      "${local.r2_bucket_resource_prefix}activity-hub-lake" = "*"
    })
  }]
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

# S3 reads the token id as the access key id and the SHA-256 of the token value
# as the secret access key. The raw token value is not the secret.

output "activity_hub_r2_raw_access_key_id" {
  description = "S3 access key id for reading activity-hub-raw"
  value       = cloudflare_account_token.hub_r2_raw.id
}

output "activity_hub_r2_raw_secret_access_key" {
  description = "S3 secret access key for reading activity-hub-raw"
  value       = sha256(cloudflare_account_token.hub_r2_raw.value)
  sensitive   = true
}

output "activity_hub_r2_lake_access_key_id" {
  description = "S3 access key id for writing activity-hub-lake"
  value       = cloudflare_account_token.hub_r2_lake.id
}

output "activity_hub_r2_lake_secret_access_key" {
  description = "S3 secret access key for writing activity-hub-lake"
  value       = sha256(cloudflare_account_token.hub_r2_lake.value)
  sensitive   = true
}

# Wrangler's own OAuth login expires within a day and cannot be refreshed
# non-interactively, which stalls any unattended work against the worker. This
# token replaces that login, and rotating it is an apply rather than a browser
# round trip.

resource "cloudflare_account_token" "hub_automation" {
  account_id = var.cloudflare_account_id
  name       = "activity-hub automation"
  expires_on = "2027-08-12T00:00:00Z"

  policies = [{
    effect            = "allow"
    permission_groups = local.automation_permission_groups

    resources = jsonencode({
      "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*"
    })
  }]

  lifecycle {
    precondition {
      # A name that stops matching yields a null id, which Cloudflare rejects
      # with an error naming neither the token nor the group.
      condition = alltrue([
        for group in local.automation_permission_groups : group.id != null
      ])
      error_message = join(" ", [
        "One of automation_permission_group_names no longer matches a Cloudflare permission group.",
        "Available account groups:",
        join(", ", sort([
          for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
          group.name
        ])),
      ])
    }
  }
}

# The admin routes authenticate a bearer token behind Access. Generating it here
# means an unattended session can read it back from state instead of asking for
# a value only the worker knows.

resource "random_password" "hub_admin" {
  length  = 48
  special = false
}

output "activity_hub_admin_token" {
  description = "Bearer token for the activity-hub /admin routes"
  value       = random_password.hub_admin.result
  sensitive   = true
}

output "activity_hub_cloudflare_api_token" {
  description = "CLOUDFLARE_API_TOKEN for wrangler against activity-hub"
  value       = cloudflare_account_token.hub_automation.value
  sensitive   = true
}
