# Bootstrap

Everything that must exist before HCP Terraform can run the root module.

The root module authenticates to AWS with OIDC, which requires an identity provider and a role to assume. Neither can be created by the run that needs them, so they live here instead. This root also owns the workspace those runs execute in.

## No secrets

State is committed to git, so nothing here may hold a secret. The workspace variables managed here are a boolean, a role ARN, and a Tailscale federated identity's client ID and audience. The workspace's Cloudflare credential stays under manual management for that reason.

## Credentials

This root runs locally rather than in HCP Terraform, so it needs its providers authenticated first.

AWS comes from IAM Identity Center, via `aws sso login`. The default profile is the read-only `View` permission set, so an apply needs `AWS_PROFILE=Administrator`. Under `View`, the plan succeeds and the apply fails with `AccessDenied`.

HCP Terraform comes from a user token in the macOS keychain, written once by `terraform login`, because the `tfe` provider has no OIDC path. That token is the one long-lived credential the Identity Center migration didn't remove. The `tfe` provider reads `TFE_TOKEN` or a credentials file and ignores the CLI's keychain credentials helper, so the token has to be exported from the helper.

Tailscale comes from an API access token generated under Settings → Keys in the admin console, with a one-day expiry, exported as `TAILSCALE_API_KEY`.

## Commands

```sh
aws sso login
export AWS_PROFILE=Administrator
export TFE_TOKEN=$(~/.terraform.d/plugins/darwin_arm64/terraform-credentials-keychain get app.terraform.io | jq -r .token)
export TAILSCALE_API_KEY=...
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply
```

Run the apply in an interactive terminal. It waits for a typed `yes`.

Commit the updated `terraform.tfstate` after an apply.
