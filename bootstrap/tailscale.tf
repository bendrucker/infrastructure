# A credential can only grant the scopes and tags it holds, so this covers
# every OAuth client the workspace creates. Tailscale generates the audience.
resource "tailscale_federated_identity" "terraform" {
  description = "HCP Terraform infrastructure workspace"
  scopes      = ["policy_file", "oauth_keys", "auth_keys"]
  tags        = ["tag:perf-vm"]
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
