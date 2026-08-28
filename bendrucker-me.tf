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

# The secret already holds this value, pasted by hand from the output this
# replaces. Naming the resource that mints it makes a rotation an apply, and
# takes the value off the path through a terminal.
resource "github_actions_secret" "bendrucker_me_ci" {
  repository      = "bendrucker.me"
  secret_name     = "CLOUDFLARE_API_TOKEN"
  plaintext_value = cloudflare_account_token.bendrucker_me_ci.value
}

# The website repo manages its own DNS record and redirect ruleset from an
# `infra/` root. Everything below is what that root needs to run: a workspace
# pointed at the repo, and a Cloudflare token narrow enough that the repo can be
# trusted with a plan.

locals {
  # One per resource the infra root manages, plus the zone read every
  # zone-scoped API call is gated on. All three groups are
  # com.cloudflare.api.account.zone, so unlike the CI token above this needs no
  # account policy at all and cannot reach Workers, R2, or D1.
  bendrucker_me_terraform_permission_group_names = [
    "Zone Read",
    "DNS Write",                   # cloudflare_dns_record.apex
    "Dynamic URL Redirects Write", # cloudflare_ruleset.redirects
  ]

  bendrucker_me_terraform_permission_groups = [
    for name in local.bendrucker_me_terraform_permission_group_names : {
      id = one([
        for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
        group.id if group.name == name
      ])
    }
  ]
}

resource "cloudflare_account_token" "bendrucker_me_terraform" {
  account_id = var.cloudflare_account_id
  name       = "bendrucker.me Terraform"
  # Same rotation cohort as the CI token above and the activity-hub tokens.
  expires_on = "2027-08-12T00:00:00Z"

  policies = [{
    effect            = "allow"
    permission_groups = local.bendrucker_me_terraform_permission_groups

    resources = jsonencode({
      "com.cloudflare.api.account.zone.${cloudflare_zone.vanity.id}" = "*"
    })
  }]

  lifecycle {
    precondition {
      # A name that stops matching yields a null id, which Cloudflare rejects
      # with an error naming neither the token nor the group.
      condition = alltrue([
        for group in local.bendrucker_me_terraform_permission_groups : group.id != null
      ])
      error_message = join(" ", [
        "A bendrucker.me Terraform permission group name no longer matches a Cloudflare permission group.",
        "Available account groups:",
        join(", ", sort([
          for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
          group.name
        ])),
      ])
    }
  }
}

module "bendrucker_me_workspace" {
  source = "./modules/app-workspace"

  name                       = "bendrucker-me"
  organization               = "bendrucker"
  repository                 = "bendrucker/bendrucker.me"
  github_app_installation_id = var.github_app_installation_id
  cloudflare_api_token       = cloudflare_account_token.bendrucker_me_terraform.value

  cloudflare_api_token_description = "Zone-scoped credential the infra root runs as. Minted in bendrucker/infrastructure."
}

# activity-hub is the second repo to get this grant, so the workspace and its
# credential variable moved into a module. Both objects already exist and are
# unchanged. Only their addresses are new.

moved {
  from = tfe_workspace.bendrucker_me
  to   = module.bendrucker_me_workspace.tfe_workspace.this
}

moved {
  from = tfe_variable.bendrucker_me_cloudflare_api_token
  to   = module.bendrucker_me_workspace.tfe_variable.cloudflare_api_token
}
