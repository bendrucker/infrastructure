# Agent workloads get their own Organizations member account, so a
# bendrucker/claude run can hold real AWS credentials with no path to the
# management account's archives, Identity Center, or the roles in
# bootstrap/. This file is the control plane for that account: it creates
# the account, lays down the OIDC provider and role the bendrucker-claude
# workspace runs as, and wires the workspace itself. The resources inside
# the account belong to that repo's own terraform root.

# The organization predates Terraform, created when Identity Center was
# enabled. Adopting it makes account creation a resource reference instead
# of a hardcoded parent, and puts the feature set and service access list
# under review.
resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # Identity Center enabled its own service access when it was turned on.
  aws_service_access_principals = ["sso.amazonaws.com"]
}

import {
  to = aws_organizations_organization.this
  id = "o-a6xqikeo35"
}

resource "aws_organizations_account" "agents" {
  name  = "agents"
  email = "bvdrucker+aws-agents@gmail.com"

  # The administrator role Organizations provisions in the member account
  # for the management account to assume. The name is the service default,
  # and bootstrap's MemberAccountAccess grant names it.
  role_name = "OrganizationAccountAccessRole"

  # Removing the resource forgets the account rather than closing it.
  # Closing an account is a 90-day process that should never ride on a
  # destroy plan.
  close_on_deletion = false

  lifecycle {
    # The Organizations API never returns role_name, so a refresh would
    # otherwise report it removed and plan a replacement.
    ignore_changes = [role_name]
  }
}

# Mirrors bootstrap/terraform-cloud.tf: the same identity provider, laid
# down inside the agents account so the workspace role can live there.
resource "aws_iam_openid_connect_provider" "agents_terraform" {
  provider = aws.agents

  url            = "https://app.terraform.io"
  client_id_list = ["aws.workload.identity"]
}

data "aws_iam_policy_document" "agents_terraform_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.agents_terraform.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "app.terraform.io:aud"
      values   = ["aws.workload.identity"]
    }

    # Same shape as bootstrap: the audience alone is identical for every
    # HCP Terraform organization, so the subject pins the organization and
    # workspace. The project segment carries no security weight, and the
    # workspace name comes from the module so a rename cannot silently
    # break the credential exchange.
    condition {
      test     = "StringLike"
      variable = "app.terraform.io:sub"
      values   = ["organization:bendrucker:project:*:workspace:${module.bendrucker_claude_workspace.name}:run_phase:*"]
    }
  }
}

resource "aws_iam_role" "agents_terraform" {
  provider = aws.agents

  name               = "terraform"
  path               = "/managed/"
  assume_role_policy = data.aws_iam_policy_document.agents_terraform_trust.json
}

# The workspace manages S3 buckets under one name prefix and nothing else:
# no IAM, no account-wide S3. Widening this is an edit to this file in this
# repo, never something a bendrucker/claude run can do to itself.
data "aws_iam_policy_document" "agents_terraform" {
  statement {
    sid     = "AgentBuckets"
    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::ben-drucker-agents-*",
      "arn:aws:s3:::ben-drucker-agents-*/*",
    ]
  }
}

resource "aws_iam_role_policy" "agents_terraform" {
  provider = aws.agents

  name   = "terraform"
  role   = aws_iam_role.agents_terraform.name
  policy = data.aws_iam_policy_document.agents_terraform.json
}

module "bendrucker_claude_workspace" {
  source = "./modules/app-workspace"

  name                       = "bendrucker-claude"
  organization               = "bendrucker"
  repository                 = "bendrucker/claude"
  github_app_installation_id = var.github_app_installation_id
}

# The dynamic-credential pair, mirroring bootstrap/variables.tf. No secret
# changes hands: each run exchanges its workload identity token for
# credentials scoped by the role above. There is no GitHub Actions role to
# go with it, deliberately: a CI credential reachable from fork pull
# requests is the leak this account exists to rule out.
resource "tfe_variable" "bendrucker_claude_aws_provider_auth" {
  workspace_id = module.bendrucker_claude_workspace.id

  category = "env"
  key      = "TFC_AWS_PROVIDER_AUTH"
  value    = "true"

  description = "Makes runs exchange their workload identity token for AWS credentials."
}

resource "tfe_variable" "bendrucker_claude_aws_run_role_arn" {
  workspace_id = module.bendrucker_claude_workspace.id

  category = "env"
  key      = "TFC_AWS_RUN_ROLE_ARN"
  value    = aws_iam_role.agents_terraform.arn

  description = "Role in the agents account that runs assume by OIDC. Minted in bendrucker/infrastructure."
}
