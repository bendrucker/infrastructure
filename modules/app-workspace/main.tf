# The Terraform Cloud workspace an app repo's terraform root runs in.
# Everything scoped to one repo stays in that repo's file at the root of this
# configuration: the credential the workspace runs as and the variables that
# carry it, which Cloudflare objects its token may touch, which GitHub secrets
# it receives.

resource "tfe_workspace" "this" {
  name         = var.name
  organization = var.organization

  auto_apply = true

  # Every app repo is an application first. Only the terraform subtree is
  # Terraform, so a content commit must not queue a run.
  working_directory = "terraform"
  trigger_patterns  = ["terraform/**"]

  vcs_repo {
    identifier                 = var.repository
    github_app_installation_id = var.github_app_installation_id
  }

  # Creating the workspace queues a run immediately, before the caller's
  # credential variables exist and before the repo has a terraform/ directory
  # to run against, so that first run errors. The next push under terraform/ is
  # the one that matters. queue_all_runs = false would suppress it, at the cost
  # of ignoring every webhook until a run is queued by hand, which is the worse
  # trade.
}
