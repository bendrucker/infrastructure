variable "name" {
  type        = string
  description = "Terraform Cloud workspace name. Workspace names cannot contain dots."
}

variable "organization" {
  type        = string
  description = "Terraform Cloud organization. Named per call rather than defaulted, so a workspace cannot land in another organization by inheriting one."
}

variable "repository" {
  type        = string
  description = "The owner/name of the GitHub repository whose infra directory this workspace runs"
}

variable "github_app_installation_id" {
  type        = string
  description = "Installation of the Terraform Cloud GitHub App that can reach the repository"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Value for the workspace's CLOUDFLARE_API_TOKEN environment variable"
  sensitive   = true
}

variable "cloudflare_api_token_description" {
  type        = string
  description = "What the credential is scoped to, shown on the variable in Terraform Cloud. The scope differs per repo, so each caller writes its own."
}
