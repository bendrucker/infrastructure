# tailscale_acl manages the tailnet policy file in its entirety, not a fragment of
# it, so this file is the sole source of truth for every rule in the tailnet.
# tailscale/policy.hujson is a verbatim capture of the live policy, taken so that
# the first plan after import is a no-op.
#
# overwrite_existing_content is deliberately unset. It defaults to false, which
# makes the provider send a "ts-default" ETag on create and refuse to clobber a
# policy that has been edited away from the default. Setting it to true to clear
# an error would trade that guard for a silent tailnet-wide overwrite.
resource "tailscale_acl" "this" {
  acl = file("tailscale/policy.hujson")
}

import {
  to = tailscale_acl.this
  id = "acl"
}
