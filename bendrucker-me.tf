# CI in the bendrucker.me repo deploys four workers and applies the D1
# migrations with a single token. The token in the repo secret predates the
# database, so `d1 migrations apply` answers 7403 and the deploy job it gates
# has never run. Minting the token here means the permission list is reviewable
# and a rotation is an apply rather than a click.

locals {
  # Mirrors the bindings across bendrucker.me's four wrangler configs: the
  # worker scripts themselves, the activity database the site and the github
  # worker share, the session and strava namespaces, and the activity-hub raw
  # bucket the photo route reads.
  bendrucker_me_permission_group_names = [
    "Workers Scripts Write",
    "D1 Write",
    "Workers KV Storage Write",
    "Workers R2 Storage Write",
    "Account Settings Read",
  ]

  # Worker routes are zone-scoped, so they cannot ride along in the account
  # policy above and need a second policy naming the zone.
  bendrucker_me_routes_write = one([
    for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
    group.id if group.name == "Workers Routes Write"
  ])

  bendrucker_me_permission_groups = [
    for name in local.bendrucker_me_permission_group_names : {
      id = one([
        for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
        group.id if group.name == name
      ])
    }
  ]
}

resource "cloudflare_account_token" "bendrucker_me_ci" {
  account_id = var.cloudflare_account_id
  name       = "bendrucker.me CI"
  # Shared with the activity-hub tokens so one rotation covers every token this
  # workspace issues.
  expires_on = "2027-08-12T00:00:00Z"

  policies = [
    {
      effect            = "allow"
      permission_groups = local.bendrucker_me_permission_groups

      resources = jsonencode({
        "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*"
      })
    },
    # The www worker declares a custom_domain route, so wrangler updates
    # /zones/{zone}/workers/routes on every deploy.
    {
      effect = "allow"

      permission_groups = [{
        id = local.bendrucker_me_routes_write
      }]

      resources = jsonencode({
        "com.cloudflare.api.account.zone.${cloudflare_zone.vanity.id}" = "*"
      })
    },
  ]

  lifecycle {
    precondition {
      # A name that stops matching yields a null id, which Cloudflare rejects
      # with an error naming neither the token nor the group.
      condition = alltrue(concat(
        [for group in local.bendrucker_me_permission_groups : group.id != null],
        [local.bendrucker_me_routes_write != null],
      ))
      error_message = join(" ", [
        "A bendrucker.me CI permission group name no longer matches a Cloudflare permission group.",
        "Available account groups:",
        join(", ", sort([
          for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
          group.name
        ])),
      ])
    }
  }
}

output "bendrucker_me_ci_cloudflare_api_token" {
  description = "CLOUDFLARE_API_TOKEN secret for the bendrucker/bendrucker.me repo"
  value       = cloudflare_account_token.bendrucker_me_ci.value
  sensitive   = true
}
