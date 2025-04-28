resource "tfe_workspace" "this" {
  name = "infrastructure"

  structured_run_output_enabled = false
  queue_all_runs = false
  auto_apply = true
  file_triggers_enabled = false
  allow_destroy_plan = false

  vcs_repo {
    identifier = "bendrucker/infrastructure"
    github_app_installation_id = "ghain-fMk4yTVFAVZbgq5H"
  }

  terraform_version = "0.13.7"
}

import {
  to = tfe_workspace.this
  id = "ws-CH5in3chf8RJjrVd"
}
