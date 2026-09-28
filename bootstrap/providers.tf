provider "tfe" {
  organization = "bendrucker"
}

# This root runs locally under IAM Identity Center credentials (`aws sso login`),
# not in HCP Terraform, so there is nothing here for OIDC to authenticate against.
provider "aws" {
  region = "us-east-1"
}

# AWS signs a token for the Identity Center session, which the tailscale
# provider exchanges with tailscale_federated_identity.bootstrap. Ephemeral
# values never reach state.
ephemeral "aws_sts_web_identity_token" "tailscale" {
  audience          = [local.tailscale_bootstrap_audience]
  signing_algorithm = "RS256"
}

# The client ID and audience are literals because a provider can't depend on a
# resource it manages.
provider "tailscale" {
  tailnet         = "tailaa2f5e.ts.net"
  oauth_client_id = local.tailscale_bootstrap_client_id
  identity_token  = ephemeral.aws_sts_web_identity_token.tailscale.web_identity_token
}
