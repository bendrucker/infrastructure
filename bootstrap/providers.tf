provider "tfe" {
  organization = "bendrucker"
}

# This root runs locally under IAM Identity Center credentials (`aws sso login`),
# not in HCP Terraform, so there is nothing here for OIDC to authenticate against.
provider "aws" {
  region = "us-east-1"
}
