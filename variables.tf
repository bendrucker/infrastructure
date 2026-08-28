variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  default     = "72bdc77341dc52a3cf4a94097f9ad96f"
}

variable "github_app_installation_id" {
  description = "Terraform Cloud GitHub App installation, the same one this workspace's own VCS connection uses in bootstrap/main.tf"
  type        = string
  default     = "ghain-fMk4yTVFAVZbgq5H"
}
