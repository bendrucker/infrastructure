# Bootstrap

Everything that must exist before HCP Terraform can run the root module.

The root module authenticates to AWS with OIDC, which requires an identity provider and a role to assume. Neither can be created by the run that needs them, so they live here instead. This root also owns the workspace those runs execute in.

## No secrets

State is committed to git, so nothing here may hold a secret. The workspace variables managed here are a boolean, a role ARN, and a Tailscale federated identity's client ID and audience. The workspace's Cloudflare credential stays under manual management for that reason.

## Credentials

This root runs locally rather than in HCP Terraform, so it needs its providers authenticated first.

AWS comes from IAM Identity Center, via `aws sso login`. The default profile is the read-only `View` permission set, so an apply needs `AWS_PROFILE=Administrator`. Under `View`, the plan succeeds and the apply fails with `AccessDenied`.

HCP Terraform comes from a user token in the macOS keychain, written once by `terraform login`, because the `tfe` provider has no OIDC path. That token is the one long-lived credential the Identity Center migration didn't remove. The `tfe` provider reads `TFE_TOKEN` or a credentials file and ignores the CLI's keychain credentials helper, so the token has to be exported from the helper.

Tailscale comes from AWS. The management account has outbound identity federation enabled, so STS signs a short-lived JWT whose subject is the Identity Center role. An ephemeral `aws_sts_web_identity_token` mints it during each run, and the `tailscale` provider exchanges it with `tailscale_federated_identity.bootstrap`. The token never reaches state.

## Commands

```sh
aws sso login
export AWS_PROFILE=Administrator
export TFE_TOKEN=$(~/.terraform.d/plugins/darwin_arm64/terraform-credentials-keychain get app.terraform.io | jq -r .token)
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply
```

Run the apply in an interactive terminal. It waits for a typed `yes`.

Commit the updated `terraform.tfstate` after an apply.

## Tailscale Identity

The `tailscale` provider authenticates as `tailscale_federated_identity.bootstrap`, so a run can't create that identity or repair it. It was created out of band and imported:

1. Enable federation with `aws iam enable-outbound-web-identity-federation`, which prints the issuer URL.
1. In the admin console's Trust credentials page, create an OpenID Connect credential with a custom issuer set to that URL. Match the subject, scopes, and tags in `tailscale.tf`.
1. Copy its client ID and audience into the locals in `tailscale.tf`. The `import` blocks adopt both resources on the next apply.

If the subject stops matching, fix the identity in the console and let the next plan reconcile it.
