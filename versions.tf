terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }

    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }

    # random_password.hub_admin is the last resource of this provider, and
    # activity-hub.tf is dropping it from state. The declaration stays until
    # that apply lands, because Terraform reads a provider's schema to decode
    # the instance it is forgetting.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }

    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.80"
    }
  }

  # `removed` with `lifecycle { destroy = false }` in dns.tf is 1.7. The old
  # 0.13 floor had already been wrong since the first `import` block, which is
  # 1.5, but nothing read it because every apply runs on the version Terraform
  # Cloud pins.
  required_version = ">= 1.7"
}
