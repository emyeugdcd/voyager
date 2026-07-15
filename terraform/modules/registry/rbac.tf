# =============================================================================
# REGISTRY ACCESS POLICIES (RBAC)
# =============================================================================
# Azure uses RBAC (Role-Based Access Control) rather than resource policies.
# The mental model: we assign a "role" (what actions are allowed) to a
# "principal" (who) over a "scope" (which resource).
#
# For ACR, Azure has two built-in roles that matter:
#   AcrPull: can pull images. What AKS nodes need.
#   AcrPush: can push images. What our CI pipeline needs.
#
# We do NOT use AcrAdmin (the username/password approach) because:
# 1. You can't rotate it per-workload if credentials leak.
# 2. It's a single point of failure — one password for everything.
# 3. Azure audit logs can't tell you which pipeline used it.
# RBAC + Managed Identity solves all three problems.
# =============================================================================

variable "aks_kubelet_identity_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of AKS kubelet managed identity principal IDs to grant AcrPull.
    
    What is the kubelet identity? AKS runs two identities per cluster:
    - Control plane identity: used by AKS to manage Azure resources (LBs, disks).
    - Kubelet identity: used by the worker NODES to pull images and interact
      with Azure APIs. This is the one that needs AcrPull.
    
    We pass this in as a list because we'll eventually have two clusters
    (test and prod) both needing to pull from this shared registry.
    The for_each below creates one role assignment per cluster automatically.
  EOT
}

variable "ci_principal_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of service principal IDs that need AcrPush (our CI runners).
    The Terraform CI service principal from Phase 1 is one candidate,
    but ideally our build pipeline has its own dedicated SP with only
    AcrPush - principle of least privilege.
  EOT
}

# AcrPull for AKS node pools
# for_each turns a list into a map so Terraform can create N resources.
# toset() deduplicates, which matters if you accidentally pass the same ID twice.
resource "azurerm_role_assignment" "acr_pull" {
  for_each = toset(var.aks_kubelet_identity_ids)

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = each.value

  # skip_service_principal_aad_check speeds up plan/apply when the principal
  # is a managed identity (not a user or SP). Azure's AAD replication can lag,
  # and this flag tells Terraform not to wait for AAD to confirm existence.
  skip_service_principal_aad_check = true
}

# AcrPush for CI pipelines
resource "azurerm_role_assignment" "acr_push" {
  for_each = toset(var.ci_principal_ids)

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = each.value

  skip_service_principal_aad_check = true
}