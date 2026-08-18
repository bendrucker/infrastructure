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

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }

  required_version = ">= 0.13"
}
