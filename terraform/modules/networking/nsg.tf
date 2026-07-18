# =============================================================================
# NETWORK SECURITY GROUPS (NSGs)
# =============================================================================
# An NSG is Azure's stateful firewall at the subnet level. "Stateful" means
# if we allow inbound traffic on port 443, the response traffic is
# automatically allowed outbound. We don't need to write a rule for both
# directions. This is different from a simple ACL.
#
# Rule priority: lower number = evaluated first. Rules stop at the first match.
# Azure adds implicit "DenyAll" rules at priority 65500. Everything not explicitly allowed is denied.
#
# We create one NSG per subnet to enforce the principle that subnets with
# different security requirements should have different rules.
# =============================================================================

# --- NSG: AKS Nodes ---

resource "azurerm_network_security_group" "nodes" {
  name                = "${var.project}-${var.environment}-nsg-nodes"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-internal-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
    # "VirtualNetwork" is an Azure service tag. It means "any IP in this VNet
    # or any peered VNet." Using service tags instead of hardcoded CIDRs means
    # our rules stay valid even if we add subnets later.
  }

  security_rule {
    name                       = "allow-ssh-from-jumphost"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.subnet_tools_cidr
    destination_address_prefix = "*"
    # Only the tools subnet (where the jumphost lives) can SSH to nodes.
    # This is how the jumphost pattern works: we SSH into the jumphost first,
    # then SSH from there to any internal resource. The nodes are never
    # directly reachable from the public internet.
  }

  security_rule {
    name                       = "allow-http-https-inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "30000-32767"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    # Explicit deny of all internet-initiated inbound traffic.
    # Azure's implicit DenyAll would catch this anyway, but being explicit
    # makes our security posture readable to auditors and teammates.
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# --- NSG: Tools / Jumphost ---

resource "azurerm_network_security_group" "tools" {
  name                = "${var.project}-${var.environment}-nsg-tools"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-ssh-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    # The jumphost is the ONE resource with a public IP and SSH open.
    # In production we would restrict source_address_prefix to our office/VPN IP.
    # For a capstone project, open is acceptable, but remember this
    # as a hardening item we would address in a real deployment.
  }

  security_rule {
    name                       = "allow-internal-vnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Associate NSGs with their subnets
resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = azurerm_subnet.nodes.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

resource "azurerm_subnet_network_security_group_association" "tools" {
  subnet_id                 = azurerm_subnet.tools.id
  network_security_group_id = azurerm_network_security_group.tools.id
}