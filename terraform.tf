terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "bendrucker"

    workspaces {
      name = "infrastructure"
    }
  }
}

