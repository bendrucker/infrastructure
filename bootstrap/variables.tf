# CLOUDFLARE_API_TOKEN, TFE_TOKEN, and GITHUB_TOKEN hold secrets that cannot
# live in committed state, so they stay under manual management.
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
