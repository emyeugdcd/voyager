output "jumphost_ssh" {
  value       = "Direct connection via public AKS endpoint enabled (no jumphost required in test)."
  description = "Access status for test environment cluster."
}

output "acr_login_server" {
  value       = data.terraform_remote_state.shared.outputs.login_server
  description = "Use this login server to tag and push your Docker images."
}

output "oidc_issuer_url" {
  value       = module.aks.oidc_issuer_url
  description = "OIDC Issuer URL of the AKS cluster. Used for configuring Workload Identity."
}

output "dns_public_zone" {
  value = module.dns.public_zone_name
}

output "dns_private_zone" {
  value = module.dns.private_zone_name
}

output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

output "db_fqdn" {
  value       = module.database.server_fqdn
  description = "FQDN of the private PostgreSQL database server."
}

output "eso_identity_client_id" {
  value       = azurerm_user_assigned_identity.eso.client_id
  description = "Client ID of the User Assigned Identity for ESO."
}

output "external_dns_identity_client_id" {
  value       = azurerm_user_assigned_identity.external_dns.client_id
  description = "Client ID of the User Assigned Identity for External DNS."
}

output "loki_storage_account_name" {
  value       = azurerm_storage_account.loki.name
  description = "Name of the Storage Account for Loki logs."
}

output "loki_identity_client_id" {
  value       = azurerm_user_assigned_identity.loki.client_id
  description = "Client ID of the Loki User Assigned Identity."
}
