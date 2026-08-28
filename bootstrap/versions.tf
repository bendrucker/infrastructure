terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.65"
    }
  }
}
