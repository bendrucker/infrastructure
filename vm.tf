# VMs join the tailnet so the laptop reaches them directly rather than only
# through Session Manager. The vm launcher in dotfiles mints a single-use auth
# key per VM from the laptop, so no Tailscale credential reaches a VM, which
# runs arbitrary code. It authenticates with a token AWS signs for its SSO
# session, so there is no client secret to store or rotate.
resource "aws_iam_outbound_web_identity_federation" "performance" {
  provider = aws.performance
}

data "aws_iam_roles" "performance_administrator" {
  provider = aws.performance

  path_prefix = "/aws-reserved/sso.amazonaws.com/"
  name_regex  = "^AWSReservedSSO_${aws_ssoadmin_permission_set.administrator.name}_"
}

resource "tailscale_federated_identity" "vm" {
  description = "vm launcher"
  scopes      = ["auth_keys"]
  tags        = ["tag:vm"]
  issuer      = aws_iam_outbound_web_identity_federation.performance.issuer_identifier
  subject     = one(data.aws_iam_roles.performance_administrator.arns)

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
