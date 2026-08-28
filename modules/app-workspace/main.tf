# The Terraform Cloud workspace an app repo's infra root runs in, and the
# Cloudflare credential it runs as. Everything scoped to one repo stays in that
# repo's file at the root of this configuration: which Cloudflare objects its
# token may touch, which GitHub secrets it receives.

resource "tfe_workspace" "this" {
  name         = var.name
  organization = var.organization

  auto_apply = true

  # Every app repo is an application first. Only the infra subtree is
  # Terraform, so a content commit must not queue a run.
  working_directory = "infra"
  trigger_patterns  = ["infra/**"]

  vcs_repo {
    identifier                 = var.repository
    github_app_installation_id = var.github_app_installation_id
  }

  # Creating the workspace queues a run immediately, before the variable below
  # exists and before the repo has an infra/ directory to run against, so that
  # first run errors. The next push under infra/ is the one that matters.
  # queue_all_runs = false would suppress it, at the cost of ignoring every
  # webhook until a run is queued by hand, which is the worse trade.
}

resource "tfe_variable" "cloudflare_api_token" {
  workspace_id = tfe_workspace.this.id

  category  = "env"
  key       = "CLOUDFLARE_API_TOKEN"
  value     = var.cloudflare_api_token
  sensitive = true

  description = "Scoped credential the infra root runs as. Minted in bendrucker/infrastructure."
}
