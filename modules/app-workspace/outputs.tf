output "id" {
  description = "Workspace ID, for the credential variables each caller attaches"
  value       = tfe_workspace.this.id
}

output "name" {
  description = "Workspace name, for OIDC trust policies that pin their subject to it"
  value       = tfe_workspace.this.name
}
