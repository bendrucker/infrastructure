provider "cloudflare" {
  version = "~> 1.0"
  email   = local.email
}

provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}
