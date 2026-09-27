# The cloudflare-tokens workspace mints and delivers app Cloudflare tokens from
# a private repository. This workspace holds the one credential that repository
# cannot mint for itself: the token that mints the others.
#
# API Tokens Write can mint a token with any grant, so this is
# admin-equivalent on the account. Zone Read resolves zone ids for zone-scoped
# grants.

data "tfe_workspace" "cloudflare_tokens" {
  name         = "cloudflare-tokens"
  organization = "bendrucker"
}

locals {
  cloudflare_tokens_account_permission_groups = [
    for name in ["Account API Tokens Write", "Account API Tokens Read"] : {
      id = one([
        for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
        group.id if group.name == name && contains(group.scopes, "com.cloudflare.api.account")
      ])
    }
  ]

  cloudflare_tokens_zone_read = one([
    for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
    group.id if group.name == "Zone Read" && contains(group.scopes, "com.cloudflare.api.account.zone")
  ])
}

resource "cloudflare_account_token" "cloudflare_tokens" {
  account_id = var.cloudflare_account_id
  name       = "cloudflare-tokens Terraform"
  expires_on = "2027-08-12T00:00:00Z"

  policies = [
    {
      effect            = "allow"
      permission_groups = local.cloudflare_tokens_account_permission_groups

      resources = jsonencode({
        "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*"
      })
    },
    {
      effect = "allow"

      permission_groups = [{
        id = local.cloudflare_tokens_zone_read
      }]

      resources = jsonencode({
        "com.cloudflare.api.account.${var.cloudflare_account_id}" = {
          "com.cloudflare.api.account.zone.*" = "*"
        }
      })
    },
  ]

  lifecycle {
    precondition {
      # A name that stops matching yields a null id, which Cloudflare rejects
      # with an error that doesn't say which token or group caused it.
      condition = alltrue(concat(
        [for group in local.cloudflare_tokens_account_permission_groups : group.id != null],
        [local.cloudflare_tokens_zone_read != null],
      ))
      error_message = join(" ", [
        "A cloudflare-tokens permission group name no longer matches a Cloudflare permission group at the scope it is looked up in.",
        "Available account groups and their scopes:",
        join(", ", sort([
          for group in data.cloudflare_account_api_token_permission_groups_list.account.result :
          "${group.name} (${join(" ", group.scopes)})"
        ])),
      ])
    }
  }
}

resource "tfe_variable" "cloudflare_tokens_cloudflare_api_token" {
  workspace_id = data.tfe_workspace.cloudflare_tokens.id

  category  = "env"
  key       = "CLOUDFLARE_API_TOKEN"
  value     = cloudflare_account_token.cloudflare_tokens.value
  sensitive = true

  description = "Mints the tokens this workspace delivers. Minted in bendrucker/infrastructure."
}
