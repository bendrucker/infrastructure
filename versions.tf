terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.0"
    }

    cloudflare = {
      source  = "gaima8/cloudflare"
      version = "~> 1.0"
    }
  }

  required_version = ">= 0.13"
}
