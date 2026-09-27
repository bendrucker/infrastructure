# VMs join the tailnet so the laptop reaches them directly rather than only
# through Session Manager. The vm launcher in dotfiles mints a single-use auth
# key per VM from the laptop, so no Tailscale credential reaches a VM, which
# runs arbitrary code. It authenticates by assuming vm-launcher and exchanging
# a token AWS signs for that role.
resource "aws_iam_outbound_web_identity_federation" "performance" {
  provider = aws.performance
}

# Trusting the account delegates to IAM, so any principal whose policy allows
# sts:AssumeRole on this role can assume it, including the SSO admin session.
data "aws_iam_policy_document" "vm_launcher_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${aws_organizations_account.performance.id}:root"]
    }
  }
}

resource "aws_iam_role" "vm_launcher" {
  provider = aws.performance

  name               = "vm-launcher"
  path               = "/managed/"
  assume_role_policy = data.aws_iam_policy_document.vm_launcher_trust.json
}

# The token describes the caller, so the action has no resource to scope and
# the conditions limit it to tokens Tailscale accepts for this identity.
data "aws_iam_policy_document" "vm_launcher" {
  statement {
    actions   = ["sts:GetWebIdentityToken"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "sts:IdentityTokenAudience"
      values   = [tailscale_federated_identity.vm.audience]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:SigningAlgorithm"
      values   = ["RS256"]
    }
  }
}

resource "aws_iam_role_policy" "vm_launcher" {
  provider = aws.performance

  role   = aws_iam_role.vm_launcher.name
  policy = data.aws_iam_policy_document.vm_launcher.json
}

resource "tailscale_federated_identity" "vm" {
  description = "vm launcher"
  scopes      = ["auth_keys"]
  tags        = ["tag:vm"]
  issuer      = aws_iam_outbound_web_identity_federation.performance.issuer_identifier
  subject     = aws_iam_role.vm_launcher.arn

  # The tag has to be defined in tagOwners before a credential can carry it.
  depends_on = [tailscale_acl.this]
}

# The launcher passes the audience to sts:GetWebIdentityToken and the ID to
# Tailscale's token exchange. Neither is secret.
resource "aws_ssm_parameter" "vm_tailscale_client_id" {
  provider = aws.performance

  name  = "/vm/tailscale-client-id"
  type  = "String"
  value = tailscale_federated_identity.vm.id
}

resource "aws_ssm_parameter" "vm_tailscale_audience" {
  provider = aws.performance

  name  = "/vm/tailscale-audience"
  type  = "String"
  value = tailscale_federated_identity.vm.audience
}
