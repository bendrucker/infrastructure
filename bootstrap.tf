# Local runs of the bootstrap root authenticate to Tailscale as this identity, by
# exchanging a token AWS signs for the Identity Center session. It lives here
# because bootstrap's provider can't create the identity it authenticates as,
# while this workspace's identity already holds every scope and tag it needs.
# Bootstrap reads the outputs below through an ephemeral tfe_outputs.
resource "aws_iam_outbound_web_identity_federation" "management" {}

import {
  to = aws_iam_outbound_web_identity_federation.management
  id = local.management_account_id
}

# Identity Center names the role after the permission set plus a generated hash,
# and replaces it if the permission set is reprovisioned. Looking it up keeps
# the subject current on the next plan.
data "aws_iam_roles" "administrator" {
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
  name_regex  = "^AWSReservedSSO_${aws_ssoadmin_permission_set.administrator.name}_[0-9a-f]+$"
}

# Scopes and tags cover everything bootstrap grants to its
# tailscale_federated_identity.terraform, plus federated_keys to manage it.
resource "tailscale_federated_identity" "bootstrap" {
  description = "bootstrap local runs"
  scopes      = ["policy_file", "oauth_keys", "federated_keys", "auth_keys"]
  tags        = ["tag:terraform"]
  issuer      = aws_iam_outbound_web_identity_federation.management.issuer_identifier
  subject     = one(data.aws_iam_roles.administrator.arns)
}

output "tailscale_bootstrap_client_id" {
  value = tailscale_federated_identity.bootstrap.id
}

output "tailscale_bootstrap_audience" {
  value = tailscale_federated_identity.bootstrap.audience
}
