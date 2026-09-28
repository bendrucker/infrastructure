# federated_keys lets the workspace create federated identities. A credential
# can only grant the scopes it holds, so the rest cover every credential the
# workspace creates. Tags come from tagOwners entries naming tag:terraform in
# tailscale/policy.hujson. Tailscale generates the audience.
resource "tailscale_federated_identity" "terraform" {
  description = "HCP Terraform infrastructure workspace"
  scopes      = ["policy_file", "oauth_keys", "auth_keys", "federated_keys"]
  tags        = ["tag:terraform"]
  issuer      = "https://app.terraform.io"
  subject     = "organization:bendrucker:project:*:workspace:${tfe_workspace.this.name}:run_phase:*"
}

# Runs receive the token as TFC_WORKLOAD_IDENTITY_TOKEN_TAILSCALE.
resource "tfe_variable" "tailscale_workload_identity_audience" {
  workspace_id = tfe_workspace.this.id

  category = "env"
  key      = "TFC_WORKLOAD_IDENTITY_AUDIENCE_TAILSCALE"
  value    = tailscale_federated_identity.terraform.audience

  description = "Makes runs request a workload identity token for Tailscale."
}

resource "tfe_variable" "tailscale_oauth_client_id" {
  workspace_id = tfe_workspace.this.id

  category = "env"
  key      = "TAILSCALE_OAUTH_CLIENT_ID"
  value    = tailscale_federated_identity.terraform.id

  description = "Federated identity runs exchange their workload identity token with."
}

import {
  to = tfe_variable.tailscale_oauth_client_id
  id = "bendrucker/infrastructure/var-kUXZoo1mAXD7s7Y4"
}

# Local runs of this root exchange a token AWS signs for the Identity Center
# session, so Tailscale access flows from `aws sso login`.
resource "aws_iam_outbound_web_identity_federation" "this" {}

# The subject is the role behind the AdministratorAccess permission set. Its
# name ends in a hash that changes if Identity Center reprovisions the role, so
# the pattern matches any hash. Only Identity Center can create roles under the
# aws-reserved path. Scopes and tags cover everything the identity grants to
# tailscale_federated_identity.terraform, plus federated_keys to manage it.
resource "tailscale_federated_identity" "bootstrap" {
  description = "bootstrap local runs"
  scopes      = ["policy_file", "oauth_keys", "federated_keys", "auth_keys"]
  tags        = ["tag:terraform"]
  issuer      = aws_iam_outbound_web_identity_federation.this.issuer_identifier
  subject     = "arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_*"
}

# Neither is secret. The README reads them to mint and exchange a token.
output "tailscale_client_id" {
  value = tailscale_federated_identity.bootstrap.id
}

output "tailscale_audience" {
  value = tailscale_federated_identity.bootstrap.audience
}
