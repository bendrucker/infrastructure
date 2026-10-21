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

  # Enabling SCPs attaches the AWS-managed FullAWSAccess policy to every
  # account, so accounts without their own policy see no change.
  # performance.tf attaches the first one.
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

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

# Nothing in the agents account serves public objects, so public access is
# blocked at the account rather than repeated per bucket. The run role
# cannot loosen this: s3:PutAccountPublicAccessBlock acts on the account,
# never on a bucket ARN, so the ben-drucker-agents-* grant does not reach
# it.
resource "aws_s3_account_public_access_block" "agents" {
  provider = aws.agents

  account_id = aws_organizations_account.agents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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

  # Named after the repo, like the infrastructure workspace. The OIDC trust
  # above follows the rename through the module's name output.
  name                       = "claude"
  organization               = "bendrucker"
  repository                 = "bendrucker/claude"
  github_app_installation_id = var.github_app_installation_id
}

# The dynamic-credential pair, mirroring bootstrap/variables.tf. No secret
# changes hands: each run exchanges its workload identity token for
# credentials scoped by the role above. bendrucker/claude's one GitHub
# Actions role, below, is reachable only from main, since a CI credential
# reachable from fork pull requests is the leak this account exists to rule
# out.
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

# Claude Code cloud sessions sign S3 requests with an AWS SigV4 network
# secret, which takes only a static key pair, so this is a user, not a role.
locals {
  agents_eval_corpus_arn = "arn:aws:s3:::ben-drucker-agents-eval-corpus"
}

resource "aws_iam_user" "agents_cloud_sessions" {
  provider = aws.agents

  name = "claude-cloud-sessions"
  path = "/managed/"
}

data "aws_iam_policy_document" "agents_cloud_sessions" {
  statement {
    sid       = "ListEvalCorpus"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [local.agents_eval_corpus_arn]
  }

  statement {
    sid       = "ReadWriteEvalCorpus"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.agents_eval_corpus_arn}/*"]
  }

  statement {
    sid       = "DeleteEvalCorpusTmp"
    actions   = ["s3:DeleteObject"]
    resources = ["${local.agents_eval_corpus_arn}/tmp/*"]
  }
}

resource "aws_iam_user_policy" "agents_cloud_sessions" {
  provider = aws.agents

  name   = "eval-corpus"
  user   = aws_iam_user.agents_cloud_sessions.name
  policy = data.aws_iam_policy_document.agents_cloud_sessions.json
}

resource "aws_iam_access_key" "agents_cloud_sessions" {
  provider = aws.agents

  user = aws_iam_user.agents_cloud_sessions.name
}

output "agents_cloud_sessions_access_key_id" {
  description = "Access key id for the Claude Code cloud environment's AWS SigV4 network secret"
  value       = aws_iam_access_key.agents_cloud_sessions.id
}

output "agents_cloud_sessions_secret_access_key" {
  description = "Secret access key for the Claude Code cloud environment's AWS SigV4 network secret"
  value       = aws_iam_access_key.agents_cloud_sessions.secret
  sensitive   = true
}

# Jobs on the bendrucker/actions-sandbox runner take AWS credentials by GitHub
# OIDC. bendrucker/claude is public, so the trust names a deployment
# environment rather than the repository: only main can deploy to it, so a
# workflow from a fork pull request never gets a token this role accepts.
resource "aws_iam_openid_connect_provider" "agents_github_actions" {
  provider = aws.agents

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "github_repository_environment" "claude_actions_sandbox" {
  repository  = "claude"
  environment = "actions-sandbox"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "claude_actions_sandbox_main" {
  repository     = "claude"
  environment    = github_repository_environment.claude_actions_sandbox.environment
  branch_pattern = "main"
}

data "aws_iam_policy_document" "agents_actions_sandbox_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.agents_github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:bendrucker/claude:environment:${github_repository_environment.claude_actions_sandbox.environment}"]
    }
  }
}

resource "aws_iam_role" "agents_actions_sandbox" {
  provider = aws.agents

  name               = "actions-sandbox"
  path               = "/managed/"
  assume_role_policy = data.aws_iam_policy_document.agents_actions_sandbox_trust.json
}

# Read and write on every bucket in the account, so the runner can take
# varied jobs, and no other service. Every bucket here carries the
# ben-drucker-agents- prefix, since the workspace role can create no other.
# Delete is included for jobs that expire their own data, like DuckLake
# cleanup and compaction.
data "aws_iam_policy_document" "agents_actions_sandbox" {
  statement {
    sid       = "ListBuckets"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    sid       = "AgentBuckets"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::ben-drucker-agents-*"]
  }

  statement {
    sid = "AgentObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["arn:aws:s3:::ben-drucker-agents-*/*"]
  }
}

resource "aws_iam_role_policy" "agents_actions_sandbox" {
  provider = aws.agents

  name   = "s3"
  role   = aws_iam_role.agents_actions_sandbox.name
  policy = data.aws_iam_policy_document.agents_actions_sandbox.json
}

resource "github_actions_environment_variable" "claude_actions_sandbox_role" {
  repository    = "claude"
  environment   = github_repository_environment.claude_actions_sandbox.environment
  variable_name = "AWS_ROLE_ARN"
  value         = aws_iam_role.agents_actions_sandbox.arn
}
