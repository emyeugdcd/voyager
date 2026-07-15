# =============================================================================
# MODULE: dns
# =============================================================================
# Provisions public and private DNS zones for the environment.
# Links private DNS zones to the environment VNet.
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "domain_name" {
  type    = string
  default = "voyager-cloud.com"
}

variable "vnet_id" {
  type = string
}

# -----------------------------------------------------------------------------
# DNS ZONES
# -----------------------------------------------------------------------------

# Public DNS Zone (e.g. test-public.voyager-cloud.com)
resource "azurerm_dns_zone" "public" {
  name                = "${var.environment}-public.${var.domain_name}"
  resource_group_name = var.resource_group_name
}

# Private DNS Zone (e.g. test-private.voyager-cloud.com)
resource "azurerm_private_dns_zone" "private" {
  name                = "${var.environment}-private.${var.domain_name}"
  resource_group_name = var.resource_group_name
}

# VNet Link for private DNS Zone
resource "azurerm_private_dns_zone_virtual_network_link" "private" {
  name                  = "${var.project}-${var.environment}-private-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private.name
  virtual_network_id    = var.vnet_id
}

# Dedicated Private DNS Zone for PostgreSQL Flexible Server (required by Azure)
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project}-${var.environment}-db.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

# VNet Link for PostgreSQL Private DNS Zone
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.project}-${var.environment}-pg-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = var.vnet_id
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "public_zone_name" {
  value = azurerm_dns_zone.public.name
}

output "private_zone_name" {
  value = azurerm_private_dns_zone.private.name
}

output "private_zone_id" {
  value = azurerm_private_dns_zone.private.id
}

output "postgres_private_zone_id" {
  value = azurerm_private_dns_zone.postgres.id
}

output "postgres_private_zone_name" {
  value = azurerm_private_dns_zone.postgres.name
}
