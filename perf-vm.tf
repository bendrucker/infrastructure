# Perf VMs join the tailnet so the laptop reaches them directly rather than
# only through Session Manager. On each launch, the perf-vm launcher in
# dotfiles reads this client's secret and mints one single-use, ephemeral auth
# key for the VM. The secret itself never reaches a VM, which runs arbitrary
# benchmark code.
#
# The client can only mint keys tagged tag:perf-vm. That tag is the one the
# tailnet policy keeps from opening connections to any other node.
resource "tailscale_oauth_client" "perf_vm" {
  description = "perf-vm launcher"
  scopes      = ["auth_keys"]
  tags        = ["tag:perf-vm"]

  # The tag has to be defined in tagOwners before a client can carry it.
  depends_on = [tailscale_acl.this]
}

# The repository is public, so the secret lives only in state and here. The
# default aws/ssm key is enough for the launcher, which reads it as the
# account's administrator.
resource "aws_ssm_parameter" "perf_vm_tailscale_oauth_client_secret" {
  provider = aws.performance

  name  = "/perf-vm/tailscale-oauth-client-secret"
  type  = "SecureString"
  value = tailscale_oauth_client.perf_vm.key
}
