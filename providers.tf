provider "cloudflare" {
  email = local.email
  # assume $CLOUDFLARE_TOKEN is set
}

provider "aws" {
  region = "us-east-1"
}