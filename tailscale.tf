# tailscale_acl manages the tailnet policy file in its entirety, not a fragment of
# it, so this file is the sole source of truth for every rule in the tailnet.
#
# overwrite_existing_content is deliberately unset. It defaults to false, which
# makes the provider send a "ts-default" ETag on create and refuse to clobber a
# policy that has been edited away from the default. Setting it to true to clear
# an error would trade that guard for a silent tailnet-wide overwrite.
locals {
  tailnet_policy = file("tailscale/policy.hujson")
}

resource "tailscale_acl" "this" {
  acl = local.tailnet_policy

  # The policy's own "tests" block covers reachability, which is all Tailscale
  # can validate server-side. Neither node attributes nor app capability grants
  # are expressible as tests, so the two invariants that decide whether tailgate
  # works at all are checked here instead, at plan time.
  lifecycle {
    precondition {
      condition     = strcontains(local.tailnet_policy, "https://tailgate.tailaa2f5e.ts.net/mcp/things")
      error_message = "The tsidp grant no longer carries tailgate's canonical resource URI. tsidp compares the RFC 8707 resource parameter against this string with ==, so any edit to it denies every request at the audience check and logs nothing above debug. Regenerate the grant with `tailgate grant` rather than editing the string."
    }
    precondition {
      condition     = strcontains(local.tailnet_policy, "\"funnel\"")
      error_message = "No node attribute grants funnel. tailgate is served over Tailscale Funnel and stops accepting public traffic without it."
    }
  }
}

import {
  to = tailscale_acl.this
  id = "acl"
}
