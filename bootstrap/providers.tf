provider "tfe" {
  organization = "bendrucker"
}

# This root runs locally under IAM Identity Center credentials (`aws sso login`),
# not in HCP Terraform, so there is nothing here for OIDC to authenticate against.
provider "aws" {
  region = "us-east-1"
}

# The root module creates the identity this provider authenticates as, since a
# provider can't create its own credential. Its client ID and audience come from
# that workspace's outputs, and AWS signs a token for the Identity Center
# session. Ephemeral values never reach state.
ephemeral "tfe_outputs" "infrastructure" {
  workspace = "infrastructure"
}

ephemeral "aws_sts_web_identity_token" "tailscale" {
  audience          = [ephemeral.tfe_outputs.infrastructure.nonsensitive_values.tailscale_bootstrap_audience]
  signing_algorithm = "RS256"
}

provider "tailscale" {
  tailnet         = "tailaa2f5e.ts.net"
  oauth_client_id = ephemeral.tfe_outputs.infrastructure.nonsensitive_values.tailscale_bootstrap_client_id
  identity_token  = ephemeral.aws_sts_web_identity_token.tailscale.web_identity_token
}
