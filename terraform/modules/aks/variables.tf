variable "resource_group_name" {
  type        = string
  description = "The resource group where AKS is deployed."
}

variable "location" {
  type        = string
  description = "The Azure region to deploy AKS to."
}

variable "project" {
  type        = string
  description = "Consistent project name prefix."
}

variable "environment" {
  type        = string
  description = "Environment (e.g. test, prod)."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "Kubernetes control plane version. Must be in standard (non-LTS) support."
}

variable "subnet_nodes_id" {
  type        = string
  description = "Subnet resource ID for AKS worker nodes."
}

variable "subnet_pods_id" {
  type        = string
  description = "Subnet resource ID for AKS pods (Azure CNI)."
}

variable "acr_id" {
  type        = string
  description = "Resource ID of the Azure Container Registry."
}

variable "enable_ha" {
  type        = bool
  default     = false
  description = "Whether to deploy the cluster with production-grade HA (Availability Zones)."
}

variable "node_count_main" {
  type        = number
  default     = 2
  description = "Initial node count for the default/main node pool."
}

variable "node_count_tools" {
  type        = number
  default     = 1
  description = "Initial node count for the tools node pool."
}

variable "node_count_monitoring" {
  type        = number
  default     = 1
  description = "Initial node count for the monitoring node pool."
}

variable "vm_size_main" {
  type        = string
  default     = "Standard_D2as_v7"
  description = "VM size for the main node pool (BS Family)."
}

variable "vm_size_tools" {
  type        = string
  default     = "Standard_D2als_v7"
  description = "VM size for the tools node pool (Dalsv7 Family)."
}

variable "vm_size_monitoring" {
  type        = string
  default     = "Standard_F2as_v7"
  description = "VM size for the monitoring node pool (Fasv7 Family)."
}

variable "service_cidr" {
  type        = string
  default     = "172.16.0.0/16"
  description = "Kubernetes internal service CIDR block."
}

variable "dns_service_ip" {
  type        = string
  default     = "172.16.0.10"
  description = "Kubernetes DNS service IP. Must be inside service_cidr."
}

variable "private_cluster_enabled" {
  type        = bool
  default     = true
  description = "Whether the AKS cluster should have a private API server."
}
