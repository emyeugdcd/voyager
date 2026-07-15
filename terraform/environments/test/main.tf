# =============================================================================
# TEST ENVIRONMENT
# =============================================================================
# Provisions all Test environment infrastructure: isolated VNet, private subnets,
# hardened VM jumphost, private AKS cluster, DNS zones, Key Vault, and private
# PostgreSQL Flexible Server.
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
    key                  = "test/terraform.tfstate"
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

resource "azurerm_resource_group" "test" {
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
  resource_group_name = azurerm_resource_group.test.name
  location            = var.location
  project             = var.project
  environment         = var.environment

  vnet_cidr          = "10.1.0.0/16"
  subnet_node_cidr   = "10.1.1.0/24"
  subnet_pod_cidr    = "10.1.2.0/24"
  subnet_tools_cidr  = "10.1.3.0/24"
  subnet_public_cidr = "10.1.4.0/24"
  subnet_db_cidr     = "10.1.5.0/24" # Added for private PostgreSQL integration
}

module "jumphost" {
  source              = "../../modules/jumphost"
  resource_group_name = azurerm_resource_group.test.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  subnet_tools_id     = module.networking.subnet_tools_id
  ssh_public_key      = var.ssh_public_key
}

module "aks" {
  source              = "../../modules/aks"
  resource_group_name = azurerm_resource_group.test.name
  location            = var.location
  project             = var.project
  environment         = var.environment

  subnet_nodes_id       = module.networking.subnet_nodes_id
  subnet_pods_id        = module.networking.subnet_pods_id
  acr_id                = data.terraform_remote_state.shared.outputs.acr_id
  enable_ha             = false # Test does not require node-level AZ HA
  node_count_main       = 2
  node_count_tools      = 1
  node_count_monitoring = 1
}

# -----------------------------------------------------------------------------
# PHASE 4: DNS, TLS, AND DATABASE SERVICES
# -----------------------------------------------------------------------------

module "dns" {
  source              = "../../modules/dns"
  resource_group_name = azurerm_resource_group.test.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  domain_name         = var.domain_name
  vnet_id             = module.networking.vnet_id
}

module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = azurerm_resource_group.test.name
  location            = var.location
  project             = var.project
  environment         = var.environment
}

module "database" {
  source              = "../../modules/database"
  resource_group_name = azurerm_resource_group.test.name
  location            = var.location
  project             = var.project
  environment         = var.environment

  subnet_db_id          = module.networking.subnet_db_id
  private_dns_zone_id   = module.dns.postgres_private_zone_id
  db_user               = module.keyvault.db_user
  db_password           = module.keyvault.db_password
  enable_ha             = false # Test database doesn't need replication HA
  backup_retention_days = 7     # Test retains 7 days of daily backups
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITIES & ROLE ASSIGNMENTS (Phase 5)
# -----------------------------------------------------------------------------

# Managed Identity for External Secrets Operator (ESO)
resource "azurerm_user_assigned_identity" "eso" {
  name                = "${var.project}-${var.environment}-eso-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.test.name
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
  resource_group_name = azurerm_resource_group.test.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.eso.id
  subject             = "system:serviceaccount:external-secrets:external-secrets-sa"
}

# Managed Identity for External DNS
resource "azurerm_user_assigned_identity" "external_dns" {
  name                = "${var.project}-${var.environment}-dns-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.test.name
}

# Grant DNS Zone Contributor role to External DNS identity
resource "azurerm_role_assignment" "dns_zone_contributor" {
  scope                = azurerm_resource_group.test.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

# Link External DNS identity to AKS service account via OIDC federation
resource "azurerm_federated_identity_credential" "external_dns" {
  name                = "${var.project}-${var.environment}-dns-federated"
  resource_group_name = azurerm_resource_group.test.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.external_dns.id
  subject             = "system:serviceaccount:external-dns:external-dns-sa"
}