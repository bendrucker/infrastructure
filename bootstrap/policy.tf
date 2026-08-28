locals {
  account_id = "278105230435"
}

# Replaces the AdministratorAccess the static key carried. Scoped to what the root
# module actually manages: two S3 archives, Identity Center, and roles under
# /managed/. Everything else in the root is Cloudflare and Tailscale, which
# authenticate on their own credentials.
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

    actions = [
      "iam:*Role*",
      "iam:*RolePolicy*",
      "iam:PassRole",
    ]

    resources = ["arn:aws:iam::${local.account_id}:role/managed/*"]
  }

  # The ManagedRoles statement matches this role's own ARN, which would let a run
  # attach AdministratorAccess to itself and make the rest of this policy
  # decorative. Nothing in the root module touches this role, so denying it costs
  # nothing.
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
