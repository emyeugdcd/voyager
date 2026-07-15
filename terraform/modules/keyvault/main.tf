# =============================================================================
# MODULE: keyvault
# =============================================================================
# Provisions an Azure Key Vault, generates a secure password, and stores
# database credentials in it.
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "project"             { type = string }
variable "environment"         { type = string }

variable "secret_reader_object_ids" {
  type        = list(string)
  default     = []
  description = "Object IDs of managed identities that should have read-only access to Key Vault secrets."
}

# Get current Azure subscription client config (caller identity details)
data "azurerm_client_config" "current" {}

# Generate a unique suffix for Key Vault name (names must be globally unique)
resource "random_id" "kv_suffix" {
  keepers = {
    location = var.location
  }
  byte_length = 4
}

# -----------------------------------------------------------------------------
# KEY VAULT
# -----------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                        = "${var.project}-${var.environment}-kv-${random_id.kv_suffix.hex}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"



  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover"
  ]
}

resource "azurerm_key_vault_access_policy" "readers" {
  for_each     = toset(var.secret_reader_object_ids)
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value

  secret_permissions = [
    "Get",
    "List"
  ]
}

# -----------------------------------------------------------------------------
# SECRETS PROVISIONING
# -----------------------------------------------------------------------------

# Generate a secure database administrator password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store database administrator username in Key Vault
resource "azurerm_key_vault_secret" "db_user" {
  name         = "pg-admin-user"
  value        = "pgadmin"
  key_vault_id = azurerm_key_vault.main.id
}

# Store database password in Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  name         = "pg-admin-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "db_user" {
  value = azurerm_key_vault_secret.db_user.value
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}
