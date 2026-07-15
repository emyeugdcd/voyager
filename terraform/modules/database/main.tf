# =============================================================================
# MODULE: database
# =============================================================================
# Provisions a private Azure Database for PostgreSQL Flexible Server in the
# delegated database subnet.
# Supports High Availability (Zone-Redundant) for production configurations.
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------

variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "project"             { type = string }
variable "environment"         { type = string }
variable "subnet_db_id"        { type = string }
variable "private_dns_zone_id" { type = string }
variable "db_user"             { type = string }
variable "db_password"         { type = string }

variable "enable_ha" {
  type        = bool
  default     = false
  description = "Enable zone-redundant High Availability for the database (requires General Purpose SKU)."
}

variable "backup_retention_days" {
  type        = number
  default     = 7
  description = "Days of backup retention (e.g. 7 for test, 30 for prod)."
}

# -----------------------------------------------------------------------------
# POSTGRESQL FLEXIBLE SERVER
# -----------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project}-${var.environment}-pg"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "15"
  
  delegated_subnet_id    = var.subnet_db_id
  private_dns_zone_id    = var.private_dns_zone_id
  zone                   = "1"
  public_network_access_enabled = false

  administrator_login    = var.db_user
  administrator_password = var.db_password

  # SKU selection: Burstable is cheapest for dev/test, General Purpose for HA prod.
  sku_name   = var.enable_ha ? "GP_Standard_D2ds_v4" : "B_Standard_B1ms"
  storage_mb = 32768  # 32 GB minimum for standard instances

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = false

  # High Availability block (only supported on non-Burstable SKUs)
  dynamic "high_availability" {
    for_each = var.enable_ha ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  # Azure Postgres Flexible Server requires ssl enabled by default.

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# -----------------------------------------------------------------------------
# DATABASE CREATION
# -----------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_database" "sampleapp" {
  name      = "sampleapp"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Disable secure transport (SSL/TLS enforcement) because the backend code uses hardcoded sslmode=disable
resource "azurerm_postgresql_flexible_server_configuration" "disable_ssl" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "off"
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "server_name" {
  value = azurerm_postgresql_flexible_server.main.name
}

output "server_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
  description = "The endpoint address of the database. Use in Helm values."
}

output "database_name" {
  value = azurerm_postgresql_flexible_server_database.sampleapp.name
}
