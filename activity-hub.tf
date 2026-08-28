# activity-hub deploys its own hostname, worker route, the Access applications
# in front of /admin and /auth, and the bearer token behind them. All of it
# moves to bendrucker/activity-hub, which adopts each object in an `infra/`
# root with import blocks. Dropping them from state here leaves the Cloudflare
# objects untouched. The zone stays: it is shared substrate.
#
# Order matters. This has to apply before the hub repo's imports land, or two
# states claim the same objects.
#
# The ids the hub repo's import blocks have to carry are recorded on each
# removed block, because deleting the resource blocks also deletes the only
# copy of them in this repo. A wrong id there does not fail loudly, it adopts
# some other object.

removed {
  from = cloudflare_dns_record.hub # c783f775892feb7781197c65222d9612/9b8c3efbca77be34a0a297d4ed834c63

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_workers_route.hub # c783f775892feb7781197c65222d9612/0f5629d62e24445396937ffa64599dec

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zero_trust_access_application.hub_admin # accounts/72bdc77341dc52a3cf4a94097f9ad96f/0bbf69f9-b54f-4b13-b7b9-b2ffc33dec60

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zero_trust_access_application.hub_auth # accounts/72bdc77341dc52a3cf4a94097f9ad96f/8737c874-5c6b-4a1e-b89e-248bd2a9533c

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zero_trust_access_policy.hub_owner # 72bdc77341dc52a3cf4a94097f9ad96f/4a5528c8-2bc2-4d8c-b8d5-b7134b5c7f28

  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zero_trust_access_policy.hub_automation # 72bdc77341dc52a3cf4a94097f9ad96f/90146498-b99b-476b-bf23-3abdd3491847

  lifecycle {
    destroy = false
  }
}

# The client_secret is write-once: Cloudflare returns it on create and never
# again, so the hub repo's import adopts the token with an empty secret in
# state. The deployed header value keeps working. Only a rotation, which
# re-issues the secret anyway, needs it back.
removed {
  from = cloudflare_zero_trust_access_service_token.hub # accounts/72bdc77341dc52a3cf4a94097f9ad96f/b2abbe4d-5586-4fee-b8c1-457d10485be4

  lifecycle {
    destroy = false
  }
}

# random_password has no id to import by. The import id is the generated value
# itself, which lives only in this workspace's state and in the worker's
# ADMIN_TOKEN secret. Adopting it in the hub repo means passing a live
# credential through a terminal, and regenerating it rotates the admin bearer
# token. That decision is open, so the hub repo declares nothing for this yet.
removed {
  from = random_password.hub_admin

  lifecycle {
    destroy = false
  }
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

# S3 reads the token id as the access key id and the SHA-256 of the token value
# as the secret access key. The raw token value is not the secret.
#
# These four reach the worker as runtime secrets, pushed with `wrangler secret
# put`, so they stay outputs.

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

# The secret already holds this value, pasted by hand from the output below.
# Naming the resource that mints it makes a rotation an apply, so the CI copy
# no longer has to be re-pasted. It is the only secret activity-hub's CI reads:
# the deploy job passes it to `wrangler d1 migrations apply` and
# `wrangler deploy`.
resource "github_actions_secret" "activity_hub_ci" {
  repository      = "activity-hub"
  secret_name     = "CLOUDFLARE_API_TOKEN"
  plaintext_value = cloudflare_account_token.hub_automation.value
}

# A GitHub secret is write-only, and the hub's readme documents this token as
# what wrangler runs under from a laptop as well. The output is the only way to
# read the value back for that.
output "activity_hub_cloudflare_api_token" {
  description = "CLOUDFLARE_API_TOKEN for wrangler against activity-hub"
  value       = cloudflare_account_token.hub_automation.value
  sensitive   = true
}

# The hub repo manages the resources the removed blocks above drop, from an
# `infra/` root. Everything below is what that root needs to run: a workspace
# pointed at the repo, and a Cloudflare token narrow enough that the repo can be
# trusted with a plan. API Tokens Write is not on it, so the hub repo cannot
# widen its own grant and the three tokens above stay minted here.

locals {
  # Access objects are account-scoped, the hostname and the route are
  # zone-scoped, so the token needs one policy of each.
  activity_hub_terraform_account_permission_group_names = [
    # cloudflare_zero_trust_access_application.hub_admin and .hub_auth, and
    # cloudflare_zero_trust_access_policy.hub_owner and .hub_automation.
    "Access: Apps and Policies Write",
    # cloudflare_zero_trust_access_service_token.hub, which the provider
    # documents as its own permission pair.
    "Access: Service Tokens Write",
  ]

  activity_hub_terraform_zone_permission_group_names = [
    "Zone Read",            # every zone-scoped call is gated on it
    "DNS Write",            # cloudflare_dns_record.hub
    "Workers Routes Write", # cloudflare_workers_route.hub
  ]

  # Seven group names exist twice, once per scope, "Access: Apps and Policies
  # Write" among them. Matching on the name alone hands one() two elements and
  # fails the apply, so each lookup names the scope it wants.
  activity_hub_terraform_account_permission_groups = [
    for name in local.activity_hub_terraform_account_permission_group_names : {
      id = one([
        for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
        group.id if group.name == name && contains(group.scopes, "com.cloudflare.api.account")
      ])
    }
  ]

  activity_hub_terraform_zone_permission_groups = [
    for name in local.activity_hub_terraform_zone_permission_group_names : {
      id = one([
        for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
        group.id if group.name == name && contains(group.scopes, "com.cloudflare.api.account.zone")
      ])
    }
  ]
}

resource "cloudflare_account_token" "activity_hub_terraform" {
  account_id = var.cloudflare_account_id
  name       = "activity-hub Terraform"
  # Same rotation cohort as the three tokens above and the bendrucker.me pair.
  expires_on = "2027-08-12T00:00:00Z"

  policies = [
    {
      effect            = "allow"
      permission_groups = local.activity_hub_terraform_account_permission_groups

      resources = jsonencode({
        "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*"
      })
    },
    {
      effect            = "allow"
      permission_groups = local.activity_hub_terraform_zone_permission_groups

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
        [for group in local.activity_hub_terraform_account_permission_groups : group.id != null],
        [for group in local.activity_hub_terraform_zone_permission_groups : group.id != null],
      ))
      error_message = join(" ", [
        "An activity-hub Terraform permission group name no longer matches a Cloudflare permission group at the scope it is looked up in.",
        "Available account groups and their scopes:",
        join(", ", sort([
          for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
          "${group.name} (${join(" ", group.scopes)})"
        ])),
      ])
    }
  }
}

module "activity_hub_workspace" {
  source = "./modules/app-workspace"

  name                       = "activity-hub"
  organization               = "bendrucker"
  repository                 = "bendrucker/activity-hub"
  github_app_installation_id = var.github_app_installation_id
  cloudflare_api_token       = cloudflare_account_token.activity_hub_terraform.value

  cloudflare_api_token_description = "Access-scoped on the account and zone-scoped on bendrucker.me. Minted in bendrucker/infrastructure."
}
