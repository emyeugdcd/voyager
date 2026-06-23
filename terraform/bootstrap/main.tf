# Purpose: Creates the Azure Storage Account that holds all Terraform remote state.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # No remote backend here, this will create backend
}

provider "azurerm" {
    features {}
}

variable "location" {
    default = "northeurope"
}

variable "project" {
    default = "voyager"
}

resource "azurerm_resource_group" "state" {
    name = "${var.project}-tfstate-rg"
    location = var.location
}

resource "azurerm_storage_account" "state" {
  name                     = "${var.project}tfstate${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"           # Geo-redundant — state is precious
  min_tls_version          = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true                # Checklist item: versioning on state bucket
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.state.name
}

output "resource_group" {
  value = azurerm_resource_group.state.name
}