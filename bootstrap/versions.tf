terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }

    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.65"
    }
  }
}
