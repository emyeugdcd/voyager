# =============================================================================
# PROD ENVIRONMENT
# =============================================================================
# Provisions all Production environment infrastructure: isolated VNet, private subnets,
# hardened VM jumphost, private AKS cluster with HA (AZ spanning), DNS zones, Key Vault,
# and private PostgreSQL Flexible Server with HA (Zone Redundant) and 30-day backups.
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
  backend "azurerm" {
    resource_group_name  = "voyager-tfstate-rg"
    storage_account_name = "voyagertfstateb25fa017"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------------
# REMOTE STATE
# -----------------------------------------------------------------------------

# Reads outputs from the shared environment (e.g. ACR details)
data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = "voyager-tfstate-rg"
    storage_account_name = "voyagertfstateb25fa017"
    container_name       = "tfstate"
    key                  = "shared/terraform.tfstate"
  }
}

# -----------------------------------------------------------------------------
# RESOURCE GROUP
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "prod" {
  name     = "${var.project}-${var.environment}-rg"
  location = var.location

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# -----------------------------------------------------------------------------
# INFRASTRUCTURE MODULE CALLS
# -----------------------------------------------------------------------------

module "networking" {
  source              = "../../modules/networking"
  resource_group_name = azurerm_resource_group.prod.name
  location            = var.location
  project             = var.project
  environment         = var.environment

  vnet_cidr          = "10.2.0.0/16"
  subnet_node_cidr   = "10.2.1.0/24"
  subnet_pod_cidr    = "10.2.2.0/24"
  subnet_tools_cidr  = "10.2.3.0/24"
  subnet_public_cidr = "10.2.4.0/24"
  subnet_db_cidr     = "10.2.5.0/24" # Added for private PostgreSQL integration
}

module "jumphost" {
  source              = "../../modules/jumphost"
  resource_group_name = azurerm_resource_group.prod.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  subnet_tools_id     = module.networking.subnet_tools_id
  ssh_public_key      = var.ssh_public_key
}

module "aks" {
  source              = "../../modules/aks"
  resource_group_name = azurerm_resource_group.prod.name
  location            = var.location
  project             = var.project
  environment         = var.environment

  subnet_nodes_id       = module.networking.subnet_nodes_id
  subnet_pods_id        = module.networking.subnet_pods_id
  acr_id                = data.terraform_remote_state.shared.outputs.acr_id
  enable_ha             = true # Production requires node-level AZ HA
  node_count_main       = 3    # Production scales default node pool
  node_count_tools      = 1
  node_count_monitoring = 1
}

# -----------------------------------------------------------------------------
# PHASE 4: DNS, TLS, AND DATABASE SERVICES
# -----------------------------------------------------------------------------

module "dns" {
  source              = "../../modules/dns"
  resource_group_name = azurerm_resource_group.prod.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  domain_name         = var.domain_name
  vnet_id             = module.networking.vnet_id
}

module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = azurerm_resource_group.prod.name
  location            = var.location
  project             = var.project
  environment         = var.environment
}

module "database" {
  source              = "../../modules/database"
  resource_group_name = azurerm_resource_group.prod.name
  location            = var.location
  project             = var.project
  environment         = var.environment

  subnet_db_id          = module.networking.subnet_db_id
  private_dns_zone_id   = module.dns.postgres_private_zone_id
  db_user               = module.keyvault.db_user
  db_password           = module.keyvault.db_password
  enable_ha             = true # Production database runs with zone-redundant HA
  backup_retention_days = 30   # Production retains 30 days of daily backups
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITIES & ROLE ASSIGNMENTS (Phase 5)
# -----------------------------------------------------------------------------

# Managed Identity for External Secrets Operator (ESO)
resource "azurerm_user_assigned_identity" "eso" {
  name                = "${var.project}-${var.environment}-eso-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.prod.name
}

# Grant Key Vault access to ESO identity
resource "azurerm_role_assignment" "eso_keyvault" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eso.principal_id
}

# Link ESO identity to AKS service account via OIDC federation
resource "azurerm_federated_identity_credential" "eso" {
  name                = "${var.project}-${var.environment}-eso-federated"
  resource_group_name = azurerm_resource_group.prod.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.eso.id
  subject             = "system:serviceaccount:external-secrets:external-secrets-sa"
}

# Managed Identity for External DNS
resource "azurerm_user_assigned_identity" "external_dns" {
  name                = "${var.project}-${var.environment}-dns-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.prod.name
}

# Grant DNS Zone Contributor role to External DNS identity
resource "azurerm_role_assignment" "dns_zone_contributor" {
  scope                = azurerm_resource_group.prod.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

# Link External DNS identity to AKS service account via OIDC federation
resource "azurerm_federated_identity_credential" "external_dns" {
  name                = "${var.project}-${var.environment}-dns-federated"
  resource_group_name = azurerm_resource_group.prod.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.external_dns.id
  subject             = "system:serviceaccount:external-dns:external-dns-sa"
}

# -----------------------------------------------------------------------------
# LOKI OBSERVABILITY STORAGE & IDENTITY (Phase 7)
# -----------------------------------------------------------------------------

resource "random_id" "loki_suffix" {
  keepers = {
    location = var.location
  }
  byte_length = 4
}

# Azure Storage Account for Loki logs (Prod HA using GRS replication)
resource "azurerm_storage_account" "loki" {
  name                     = "voyagerloki${var.environment}${random_id.loki_suffix.hex}"
  resource_group_name      = azurerm_resource_group.prod.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

# Container for Loki logs
resource "azurerm_storage_container" "loki" {
  name                  = "loki-logs"
  storage_account_name  = azurerm_storage_account.loki.name
  container_access_type = "private"
}

# Lifecycle policy: delete logs older than 365 days
resource "azurerm_storage_management_policy" "loki" {
  storage_account_id = azurerm_storage_account.loki.id

  rule {
    name    = "loki-logs-retention"
    enabled = true
    filters {
      prefix_match = ["loki-logs/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 365
      }
    }
  }
}

# Managed Identity for Loki
resource "azurerm_user_assigned_identity" "loki" {
  name                = "${var.project}-${var.environment}-loki-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.prod.name
}

# Grant Storage Blob Data Contributor role to Loki identity over storage scope
resource "azurerm_role_assignment" "loki_storage" {
  scope                = azurerm_storage_account.loki.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.loki.principal_id
}

# Link Loki identity to AKS service account via OIDC federation
resource "azurerm_federated_identity_credential" "loki" {
  name                = "${var.project}-${var.environment}-loki-federated"
  resource_group_name = azurerm_resource_group.prod.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.loki.id
  subject             = "system:serviceaccount:monitoring:loki-sa"
}