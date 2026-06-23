data "azurerm_client_config" "current" {}

output "ARM_CLIENT_ID" {
  value       = azuread_service_principal.terraform.client_id
  description = "The Client ID (Application ID) for the Service Principal."
}

output "ARM_CLIENT_SECRET" {
  value       = azuread_service_principal_password.terraform.value
  description = "The password/secret for the Service Principal."
  sensitive   = true
}

output "ARM_TENANT_ID" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "The Tenant ID for the Azure Subscription."
}

output "ARM_SUBSCRIPTION_ID" {
  value       = data.azurerm_client_config.current.subscription_id
  description = "The Subscription ID."
}
