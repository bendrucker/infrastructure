# Bootstrap

Everything that must exist before HCP Terraform can run the root module.

The root module authenticates to AWS with OIDC, which requires an identity provider and a role to assume. Neither can be created by the run that needs them, so they live here instead. This root also owns the workspace those runs execute in.

## No secrets

State is committed to git, so nothing here may hold a secret. The two workspace variables managed in `variables.tf` are a boolean and a role ARN. The workspace's Cloudflare and Tailscale credentials stay under manual management for that reason.

## Credentials

This root runs locally rather than in HCP Terraform, so it needs both of its providers authenticated first.

AWS comes from IAM Identity Center, via `aws sso login`. HCP Terraform comes from a user token in the macOS keychain, written once by `terraform login`, because the `tfe` provider has no OIDC path. That token is the one long-lived credential the Identity Center migration didn't remove.

## Commands

```sh
aws sso login
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply
```

Commit the updated `terraform.tfstate` after an apply.
