locals {
  account_id = "278105230435"
}

# Narrows the AdministratorAccess the static key carried down to what the root
# module actually manages: two S3 archives, Identity Center, and roles under
# /managed/. Everything else in the root is Cloudflare and Tailscale, which
# authenticate on their own credentials.
#
# This narrows the surface. It does not make the role non-administrative, and it
# should not be read as if it did. Two grants below remain admin-equivalent to
# anyone who can execute code in a run:
#
#   - IdentityCenter grants sso:* and identitystore:* on "*", because Identity
#     Center has no resource-level support. CreateUser plus CreateAccountAssignment
#     against the existing AdministratorAccess permission set mints a new admin.
#   - ManagedRoles can create a role under /managed/ with a trust policy copied
#     from this one and an inline policy of its choosing, then assume it.
#   - MemberAccountAccess assumes OrganizationAccountAccessRole, which is
#     administrator inside every member account. Member accounts isolate
#     workloads from each other and from this account, never from the control
#     plane that creates them.
#
# Closing those needs a read-only role for the plan phase and a permissions
# boundary on role creation. Both are follow-up work, tracked separately. The
# status quo before this file existed was a static key holding the
# AdministratorAccess managed policy outright, so this is a narrowing either way.
data "aws_iam_policy_document" "terraform" {
  statement {
    sid     = "Archives"
    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::ben-drucker-documents",
      "arn:aws:s3:::ben-drucker-documents/*",
      "arn:aws:s3:::ben-drucker-photos",
      "arn:aws:s3:::ben-drucker-photos/*",
    ]
  }

  # Identity Center has almost no resource-level support, so these are scoped by
  # action only.
  statement {
    sid = "IdentityCenter"

    actions = [
      "sso:*",
      "sso-directory:*",
      "identitystore:*",
    ]

    resources = ["*"]
  }

  statement {
    sid = "Organizations"

    actions = [
      "organizations:Describe*",
      "organizations:List*",
    ]

    resources = ["*"]
  }

  # The root module creates member accounts for isolated workloads (agents.tf).
  # CloseAccount and LeaveOrganization are withheld: the control plane can
  # create accounts and can never destroy one.
  statement {
    sid = "OrganizationsAccounts"

    actions = [
      "organizations:CreateAccount",
      "organizations:MoveAccount",
      "organizations:TagResource",
    ]

    resources = ["*"]
  }

  # OrganizationAccountAccessRole is the administrator role Organizations
  # provisions in every member account it creates. Assuming it is how the root
  # module reaches into a member account to lay down that account's own OIDC
  # provider and workspace role. See the header for what this grant is worth.
  statement {
    sid       = "MemberAccountAccess"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/OrganizationAccountAccessRole"]
  }

  # Creating account assignments from the organization's management account needs
  # IAM permissions on the roles Identity Center provisions, which the sso:* actions
  # above do not cover.
  # https://docs.aws.amazon.com/singlesignon/latest/userguide/iam-auth-access-using-id-policies.html
  statement {
    sid = "IdentityCenterProvisionedRoles"

    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]

    resources = ["arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/*"]
  }

  statement {
    sid       = "IdentityCenterSAMLProvider"
    actions   = ["iam:GetSAMLProvider"]
    resources = ["arn:aws:iam::${local.account_id}:saml-provider/AWSSSO_*_DO_NOT_DELETE"]
  }

  # ListRoles and ListPolicies have no resource-level support. Identity Center
  # assignment management requires both.
  statement {
    sid = "IdentityCenterListing"

    actions = [
      "iam:ListRoles",
      "iam:ListPolicies",
    ]

    resources = ["*"]
  }

  statement {
    sid = "ManagedRoles"

    # iam:*Role* already matches every role-policy action (ListRolePolicies,
    # PutRolePolicy, AttachRolePolicy) and PassRole, so listing those separately
    # would suggest a narrowing that removing them would not actually make.
    actions = ["iam:*Role*"]

    resources = ["arn:aws:iam::${local.account_id}:role/managed/*"]
  }

  # ManagedRoles matches this role's own ARN, so without this a run could attach
  # AdministratorAccess directly to the role it is already using. Nothing in the
  # root module touches this role, so denying it costs nothing. It closes the
  # laziest path to admin, not every path: see the header comment.
  statement {
    sid       = "DenySelfModification"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = [aws_iam_role.terraform.arn]
  }

  statement {
    sid       = "GitHubActionsProvider"
    actions   = ["iam:*OpenIDConnectProvider*"]
    resources = ["arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"]
  }
}

resource "aws_iam_role_policy" "terraform" {
  name   = "terraform"
  role   = aws_iam_role.terraform.name
  policy = data.aws_iam_policy_document.terraform.json
}
