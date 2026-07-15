# =============================================================================
# MODULE: networking
# =============================================================================
# This module provisions the entire network layer for one environment (test
# or prod). We'll call it twice — once per environment — with different
# CIDR ranges so the two networks never overlap.
#
# Why does overlap matter? In the future, if we peer the test and prod VNets
# together (for shared services, or a bastion), Azure rejects peering between
# networks with overlapping address spaces. Designing non-overlapping CIDRs
# from day one is a professional habit that prevents painful refactoring later.
#
# CIDR plan for Voyager:
#   shared:  10.0.0.0/16  (ACR, state — no VNet needed, just storage)
#   test:    10.1.0.0/16
#   prod:    10.2.0.0/16
#
# Within each /16 we carve out subnets:
#   10.x.1.0/24  — AKS nodes (private)
#   10.x.2.0/24  — AKS pods  (private, separate for CNI)
#   10.x.3.0/24  — Tools / jumphost (private)
#   10.x.4.0/24  — Public-facing (NAT Gateway, Load Balancer)
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "project"             { type = string }
variable "environment"         { type = string }

variable "vnet_cidr" {
  type        = string
  description = "The /16 address space for this environment. e.g. 10.1.0.0/16 for test."
}

variable "subnet_node_cidr" {
  type        = string
  description = "Subnet for AKS worker nodes. e.g. 10.1.1.0/24"
}

variable "subnet_pod_cidr" {
  type        = string
  description = <<-EOT
    Subnet for AKS pods when using Azure CNI.
    
    Azure CNI (Container Network Interface) assigns real VNet IPs directly to
    pods, unlike kubenet which uses a hidden overlay network. Real VNet IPs
    means pods are directly routable from anywhere in the VNet, which is
    required for private AKS + internal load balancers. The tradeoff: we need
    a larger address space because every pod consumes a real IP.
  EOT
}

variable "subnet_tools_cidr" {
  type        = string
  description = "Subnet for the jumphost VM and any internal tooling."
}

variable "subnet_public_cidr" {
  type        = string
  description = "Public subnet for NAT Gateway and external Load Balancer."
}

variable "subnet_db_cidr" {
  type        = string
  description = "Delegated subnet for PostgreSQL Flexible Server."
}

# =============================================================================
# VIRTUAL NETWORK
# =============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.project}-${var.environment}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# =============================================================================
# SUBNETS
# =============================================================================
# A subnet is a slice of the VNet's address space assigned to a specific
# purpose. Resources in the same subnet can talk to each other freely.
# Traffic between subnets flows through the VNet router (always on, invisible)
# but can be filtered by Network Security Groups (NSGs), see nsg.tf.

resource "azurerm_subnet" "nodes" {
  name                 = "snet-nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_node_cidr]
}

resource "azurerm_subnet" "pods" {
  name                 = "snet-pods"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_pod_cidr]
}

resource "azurerm_subnet" "tools" {
  name                 = "snet-tools"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_tools_cidr]
}

resource "azurerm_subnet" "public" {
  name                 = "snet-public"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_public_cidr]
}

resource "azurerm_subnet" "database" {
  name                 = "snet-db"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_db_cidr]

  delegation {
    name = "fs-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# =============================================================================
# NAT GATEWAY
# =============================================================================
# Private nodes have no public IP, so they can't reach the internet directly.
# They need a NAT Gateway in the public subnet to translate their private
# source IPs to a single public IP for outbound traffic.
#
# What do private nodes need the internet for?
#   - Pulling container images from ACR (though ACR can also be private-linked)
#   - Downloading Helm charts during ArgoCD sync
#   - Reaching Azure APIs (Key Vault, Managed Identity endpoints)
#   - OS package updates
#
# The NAT Gateway gives them outbound internet without exposing any inbound
# ports, nothing from the internet can initiate a connection to the nodes.
# That's the security win of a private cluster.
# =============================================================================

resource "azurerm_public_ip" "nat" {
  name                = "${var.project}-${var.environment}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  # Static means this IP doesn't change between reboots or redeployments.
  # Important for NAT: if the IP changes, any firewall allowlists break.
  sku = "Standard"
  # Standard SKU is required for NAT Gateway. Basic SKU won't work here.
}

resource "azurerm_nat_gateway" "main" {
  name                    = "${var.project}-${var.environment}-natgw"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  # idle_timeout: how long to keep a NAT translation entry alive with no traffic.
  # 10 minutes is the default and fine for most workloads.
}

# Wire the public IP to the NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# Wire the NAT Gateway to the private subnets that need outbound internet
resource "azurerm_subnet_nat_gateway_association" "nodes" {
  subnet_id      = azurerm_subnet.nodes.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

resource "azurerm_subnet_nat_gateway_association" "pods" {
  subnet_id      = azurerm_subnet.pods.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "vnet_id"           { value = azurerm_virtual_network.main.id }
output "vnet_name"         { value = azurerm_virtual_network.main.name }
output "subnet_nodes_id"   { value = azurerm_subnet.nodes.id }
output "subnet_pods_id"    { value = azurerm_subnet.pods.id }
output "subnet_tools_id"   { value = azurerm_subnet.tools.id }
output "subnet_public_id"  { value = azurerm_subnet.public.id }
output "subnet_db_id"      { value = azurerm_subnet.database.id }
output "nat_gateway_id"    { value = azurerm_nat_gateway.main.id }
output "nat_public_ip"     { value = azurerm_public_ip.nat.ip_address }