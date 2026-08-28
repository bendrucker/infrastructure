# Bootstrap

Everything that must exist before HCP Terraform can run the root module.

The root module authenticates to AWS with OIDC, which requires an identity provider
and a role to assume. Neither can be created by the run that needs them, so they
live here instead. This root also owns the workspace those runs execute in.

## Contract

Runs locally under IAM Identity Center credentials (`aws sso login`), not in HCP
Terraform. State is committed to git, so nothing here may hold a secret. The two
workspace variables managed in `variables.tf` are a boolean and a role ARN. The
workspace's Cloudflare and Tailscale credentials stay under manual management for
that reason.

```
aws sso login
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply
```

## Residual credential

The `tfe` provider has no OIDC path, so this root authenticates to HCP Terraform
with a user token from the macOS keychain, written by `terraform login`. That token
is the one long-lived credential the migration to Identity Center could not remove.
