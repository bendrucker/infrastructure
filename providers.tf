provider "cloudflare" {
  email = "bvdrucker@gmail.com"
}

provider "aws" {
  region = "us-east-1"
}

# Credentials come from TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET,
# set as environment variables on the Terraform Cloud workspace. The tailnet is named
# explicitly rather than left to default to "-" (whichever tailnet owns the
# credentials), so a wrong OAuth client fails the API call instead of rewriting a
# different tailnet's policy file.
provider "tailscale" {
  tailnet = "tailaa2f5e.ts.net"
}
