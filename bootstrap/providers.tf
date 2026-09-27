provider "tfe" {
  organization = "bendrucker"
}

# This root runs locally under IAM Identity Center credentials (`aws sso login`),
# not in HCP Terraform, so there is nothing here for OIDC to authenticate against.
provider "aws" {
  region = "us-east-1"
}

# Credentials come from TAILSCALE_API_KEY, a short-lived API access token.
provider "tailscale" {
  tailnet = "tailaa2f5e.ts.net"
}
