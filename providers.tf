provider "cloudflare" {
  email = "bvdrucker@gmail.com"
}

provider "aws" {
  region = "us-east-1"
}

# The agents member account, reached through the administrator role
# Organizations provisioned at account creation. Only agents.tf's in-account
# plumbing uses this alias. Agent workloads themselves run in the
# bendrucker-claude workspace, under a role scoped to their own buckets.
provider "aws" {
  alias  = "agents"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.agents.id}:role/OrganizationAccountAccessRole"
  }
}

# Credentials come from TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET,
# set as environment variables on the Terraform Cloud workspace. The tailnet is named
# explicitly rather than left to default to "-" (whichever tailnet owns the
# credentials), so a wrong OAuth client fails the API call instead of rewriting a
# different tailnet's policy file.
provider "tailscale" {
  tailnet = "tailaa2f5e.ts.net"
}

# Both of the providers below read their credential from an environment variable
# set as a sensitive variable on this workspace: TFE_TOKEN for tfe, GITHUB_TOKEN
# for github. Neither value can live in this repository.

# The organization is named on each resource rather than here, so a workspace
# this root creates cannot land in a different organization by inheriting one.
provider "tfe" {}

provider "github" {
  owner = "bendrucker"
}
