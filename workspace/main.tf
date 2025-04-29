resource "tfe_workspace" "this" {
  name = "infrastructure"

  auto_apply = true

  vcs_repo {
    identifier                 = "bendrucker/infrastructure"
    github_app_installation_id = "ghain-fMk4yTVFAVZbgq5H"
  }
}

import {
  to = tfe_workspace.this
  id = "ws-CH5in3chf8RJjrVd"
}
