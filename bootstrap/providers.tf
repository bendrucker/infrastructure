provider "tfe" {
  organization = "bendrucker"
}

# This root runs locally under IAM Identity Center credentials (`aws sso login`),
# not in HCP Terraform, so there is nothing here for OIDC to authenticate against.
provider "aws" {
  region = "us-east-1"
}

# Credentials come from TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_IDENTITY_TOKEN,
# an AWS web identity token exchanged with tailscale_federated_identity.bootstrap.
# Provider configuration never reaches state.
provider "tailscale" {
  tailnet = "tailaa2f5e.ts.net"
}
