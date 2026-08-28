# Only the dynamic-credential pair is managed here. CLOUDFLARE_API_TOKEN,
# TAILSCALE_OAUTH_CLIENT_ID, and TAILSCALE_OAUTH_CLIENT_SECRET hold secrets whose
# values cannot live in git alongside this root's committed state, so they stay
# under manual management in the workspace.
resource "tfe_variable" "aws_provider_auth" {
  workspace_id = tfe_workspace.this.id

  category = "env"
  key      = "TFC_AWS_PROVIDER_AUTH"
  value    = "true"

  description = "Makes runs exchange their workload identity token for AWS credentials."
}

resource "tfe_variable" "aws_run_role_arn" {
  workspace_id = tfe_workspace.this.id

  category = "env"
  key      = "TFC_AWS_RUN_ROLE_ARN"
  value    = aws_iam_role.terraform.arn

  description = "Role runs assume by OIDC, in place of a static access key."
}
