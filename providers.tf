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

# The performance member account, reached the same way. performance.tf lays
# down everything inside it, since no app workspace runs there.
provider "aws" {
  alias  = "performance"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.performance.id}:role/OrganizationAccountAccessRole"
  }
}

# Authenticates by workload identity federation, configured in
# bootstrap/tailscale.tf. The tailnet is named explicitly so a wrong client ID
# fails instead of rewriting a different tailnet's policy file.
provider "tailscale" {
  tailnet = "tailaa2f5e.ts.net"

  identity_token_environment_variable_name = "TFC_WORKLOAD_IDENTITY_TOKEN_TAILSCALE"
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
