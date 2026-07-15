# =============================================================================
# MODULE: aks
# =============================================================================
# Provisions a private AKS cluster with:
#   - User-Assigned Managed Identity for the control plane.
#   - Dynamic Azure CNI networking (nodes and pods in separate subnets).
#   - Multi-AZ HA support if enabled.
#   - Workload Identity and OIDC issuer enabled.
#   - Three node pools: main, tools, and monitoring.
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
# CONTROL PLANE IDENTITY & RBAC
# -----------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = "${var.project}-${var.environment}-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Give the cluster identity permission to join and manage nodes subnet
resource "azurerm_role_assignment" "aks_network_contributor_nodes" {
  scope                = var.subnet_nodes_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

# Give the cluster identity permission to join and manage pods subnet
resource "azurerm_role_assignment" "aks_network_contributor_pods" {
  scope                = var.subnet_pods_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

# -----------------------------------------------------------------------------
# LOG ANALYTICS (Azure Monitor)
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.project}-${var.environment}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# -----------------------------------------------------------------------------
# AKS CLUSTER
# -----------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project}-${var.environment}"
  kubernetes_version  = var.kubernetes_version

  # Private Cluster: API Server is accessible only internally
  private_cluster_enabled = true
  private_dns_zone_id     = "System"

  # Modern authentication
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name            = "main"
    node_count      = var.node_count_main
    vm_size         = var.vm_size
    vnet_subnet_id  = var.subnet_nodes_id
    pod_subnet_id   = var.subnet_pods_id
    os_disk_size_gb = 50
    os_disk_type    = "Managed"

    # Spread nodes across availability zones for HA if enabled
    zones = var.enable_ha ? ["1", "2", "3"] : null

    node_labels = {
      "role"        = "main"
      "environment" = var.environment
    }
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure" # Enforces Network Policies
    load_balancer_sku = "standard"
    outbound_type     = "userAssignedNATGateway" # Directs egress traffic through NAT Gateway

    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_control_plane.id]
  }

  # RBAC Azure Active Directory integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }

  lifecycle {
    ignore_changes = [kubernetes_version]
  }

  # Ensure role assignments are applied before cluster tries to provision subnets
  depends_on = [
    azurerm_role_assignment.aks_network_contributor_nodes,
    azurerm_role_assignment.aks_network_contributor_pods
  ]
}

# -----------------------------------------------------------------------------
# ADDITIONAL NODE POOLS
# -----------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "tools" {
  name                  = "tools"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.vm_size
  node_count            = var.node_count_tools
  vnet_subnet_id        = var.subnet_nodes_id
  pod_subnet_id         = var.subnet_pods_id
  os_disk_size_gb       = 50
  os_disk_type          = "Managed"
  mode                  = "User"

  zones = var.enable_ha ? ["1", "2", "3"] : null

  node_labels = {
    "role" = "tools"
  }

  node_taints = [
    "role=tools:NoSchedule"
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "monitoring" {
  name                  = "monitoring"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.vm_size
  node_count            = var.node_count_monitoring
  vnet_subnet_id        = var.subnet_nodes_id
  pod_subnet_id         = var.subnet_pods_id
  os_disk_size_gb       = 60
  os_disk_type          = "Managed"
  mode                  = "User"

  zones = var.enable_ha ? ["1", "2", "3"] : null

  node_labels = {
    "role" = "monitoring"
  }

  node_taints = [
    "role=monitoring:NoSchedule"
  ]
}

# -----------------------------------------------------------------------------
# ACR INTEGRATION (RBAC assignment for AKS to pull images)
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "kubelet_identity_id" {
  value = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}