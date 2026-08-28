output "id" {
  description = "Workspace ID, for the credential variables each caller attaches"
  value       = tfe_workspace.this.id
}
