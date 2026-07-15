# =============================================================================
# MODULE: registry
# =============================================================================
# This module creates Azure Container Registry (ACR) —¨ the private Docker
# registry where our built images live before AKS pulls them.
#
# In AWS this would be ECR. In GCP, Artifact Registry. Azure's version is ACR.
#
# Why a module? Because modules let us reuse this logic across environments.
# If we ever needed a registry in both test and prod, we'd just call this
# module twice with different inputs. For Voyager we create it once in "shared"
# so both test and prod AKS clusters can pull from the same place.
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
# These are the "inputs" to this module. The calling environment fills these in.
# -----------------------------------------------------------------------------

variable "resource_group_name" {
  type        = string
  description = "The resource group to deploy ACR into."
}

variable "location" {
  type        = string
  description = "Azure region. For Voyager, northeurope or swedencentral."
}

variable "project" {
  type        = string
  description = "Project name prefix. Used to name resources consistently."
}

variable "environment" {
  type        = string
  description = "Environment label (shared, test, prod)."
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = <<-EOT
    ACR has three tiers:
    - Basic:    Cheapest. Fine for dev/learning. No geo-replication.
    - Standard: Adds content trust and more storage. Most teams use this.
    - Premium:  Adds geo-replication, private endpoints, customer-managed keys.
    For Voyager, Basic saves money. In a real job, we'd use Standard minimum.
  EOT
}

variable "untagged_retention_days" {
  type        = number
  default     = 14
  description = <<-EOT
    How many days to keep untagged images before auto-deleting them.
    Why does this matter? Every CI build pushes a new image. If we don't
    clean up, the registry fills with orphaned layers and we pay for storage
    we'll never use. This is a basic FinOps hygiene rule.
  EOT
}

variable "admin_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
    The ACR admin account is a single shared username/password for the whole
    registry. It exists for quick testing but is a security anti-pattern —
    we can't audit who used it or revoke it per-workload.
    We leave this false and use Workload Identity / RBAC instead.
  EOT
}

# -----------------------------------------------------------------------------
# AZURE CONTAINER REGISTRY
# -----------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  name                = "${var.project}acr${var.environment}"
  # ACR names must be globally unique across all of Azure, alphanumeric only.
  # The environment suffix (shared/test/prod) differentiates if we ever
  # spin up multiple registries. For Voyager we'll only have "shared".

  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Why zone_redundancy_enabled is not set:
  # Zone redundancy (spreading across AZs) requires Premium SKU.
  # For a capstone project, Basic is the right cost/risk tradeoff.

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    # Tagging everything with managed_by = "terraform" is a professional habit.
    # When someone looks at a resource in the portal 6 months later, they know
    # not to manually edit it because it will be overwritten on the next apply.
  }
}

# -----------------------------------------------------------------------------
# LIFECYCLE POLICY: Auto-delete untagged images
# -----------------------------------------------------------------------------
# This is the checklist item: "Configure image lifecycle rules (e.g., auto-clean
# untagged images after 14 days) to save storage costs."
#
# How ACR retention works:
# When our CI pipeline builds image foo:latest, it pushes a new image digest.
# The old digest becomes "untagged", meaning it exists in the registry but nothing
# refers to it by name anymore. Without a policy, these pile up forever.
# With this policy, Azure deletes them after N days automatically.
#
# NOTE: Retention policies require the registry to be SKU Standard or Premium.
# Since we are using Basic for cost reasons, we will comment this resource out and note
# it as a "would enable in production" decision.
# -----------------------------------------------------------------------------

#resource "azurerm_container_registry_task" "retention" {
  # We use a purge task (a scheduled ACR Task) instead of the retention policy
  # resource because retention policies require Standard/Premium SKU.
  # An ACR Task runs on a cron schedule and calls the built-in "purge" command.
  # This achieves the same result on Basic SKU — a legitimate production trick.

  #name                  = "purge-untagged-images"
  #container_registry_id = azurerm_container_registry.main.id

  #platform {
  #  os = "Linux"
  #}

  #encoded_step {
    # The purge command syntax: --filter matches repositories, --ago is the age
    # threshold, --untagged targets only untagged manifests (not your live tags).
    # ".*" means "all repositories in this registry."
    #task_content = base64encode(<<-YAML
      #version: v1.1.0
      #steps:
        #- cmd: acr purge --filter '.*:.*' --ago ${var.untagged_retention_days}d --untagged
          #disableWorkingDirectoryOverride: true
          #timeout: 3600
    #YAML
    #)
  #}

  #timer_trigger {
    #name     = "daily-purge"
    #schedule = "0 2 * * *"
    # Runs at 02:00 UTC daily — a quiet hour for Nordic-based workloads.
    # Cron format: minute hour day-of-month month day-of-week
  #}
#}

# -----------------------------------------------------------------------------
# OUTPUTS
# These are the "return values" of the module — the calling environment
# uses these to wire this module's resources into other modules.
# For example: the AKS module needs the ACR ID to grant pull permissions.
# -----------------------------------------------------------------------------

output "acr_id" {
  value       = azurerm_container_registry.main.id
  description = "Full resource ID of the ACR. Used to assign RBAC roles."
}

output "acr_name" {
  value       = azurerm_container_registry.main.name
  description = "The registry name. Used in docker login and CI push commands."
}

output "login_server" {
  value       = azurerm_container_registry.main.login_server
  description = <<-EOT
    The FQDN of the registry, e.g. voyageracrshared.azurecr.io.
    This is what you put in your Docker image tags:
      docker build -t voyageracrshared.azurecr.io/backend:v1.0.0 .
      docker push voyageracrshared.azurecr.io/backend:v1.0.0
  EOT
}