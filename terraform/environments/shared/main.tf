# In Azure, "IAM Admin User" maps to a Service Principal with scoped permissions
# Never use personal account or Owner role for Terraform

terraform {
  backend "azurerm" {
    resource_group_name  = "voyager-tfstate-rg"
    storage_account_name = "voyagertfstateb25fa017"
    container_name       = "tfstate"
    key                  = "shared/terraform.tfstate"  
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Define variables and service principal that will be used by GitLab CI to run Terraform

resource "azurerm_resource_group" "shared" {
  name     = "${var.project}-shared-rg"
  location = var.location

  tags = {
    project    = var.project
    managed_by = "terraform"
  }
}

# This Service Principal is used by GitLab CI to run Terraform
resource "azuread_application" "terraform" {
  display_name = "voyager-terraform-ci"
}

resource "azuread_service_principal" "terraform" {
  client_id = azuread_application.terraform.client_id
}

resource "azuread_service_principal_password" "terraform" {
  service_principal_id = azuread_service_principal.terraform.id
  end_date             = timeadd(timestamp(), "8760h") # 1 year

  lifecycle {
    ignore_changes = [
      end_date
    ]
  }
}

# Scoped to subscription, we will tighten to specific resource groups once they exist
resource "azurerm_role_assignment" "terraform_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.terraform.object_id
}

# Billing alerts

resource "azurerm_consumption_budget_subscription" "main" {
  name            = "voyager-monthly-budget"
  subscription_id = "/subscriptions/${var.subscription_id}"

  amount     = var.monthly_budget_eur
  time_grain = "Monthly"

  time_period {
    start_date = "2026-06-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 25
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 75
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }
}




# =============================================================================
# CALL THE REGISTRY MODULE
# =============================================================================
# This is the module call pattern. We defined the logic in modules/registry,
# and here we "instantiate" it with Voyager-specific values.
# If we ever need a second registry (say, for a different region), we'll add
# another module block with different inputs, thus no need to copy-paste code logic.
# =============================================================================

module "registry" {
  source = "../../modules/registry"

  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  project             = var.project
  environment         = "shared"
  sku                 = "Basic"       # Upgrade to Standard in a real prod setup

  untagged_retention_days = 14
  
  aks_kubelet_identity_ids = []
  ci_principal_ids         = []
}


output "acr_id" {
  value       = module.registry.acr_id
  description = "Pass this to AKS module in Phase 3 for RBAC wiring."
}

output "acr_name" {
  value       = module.registry.acr_name
}

output "login_server" {
  value       = module.registry.login_server
  description = "Use this as the image prefix in your Helm values and CI pipeline."
}