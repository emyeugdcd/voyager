# =============================================================================
# MODULE: jumphost
# =============================================================================
# This replaces Azure Bastion entirely. Cost comparison:
#
#   Azure Bastion (Basic):  ~€130/month, always on
#   This VM (B1s, stopped): ~€0/month when deallocated, ~€7/month if running
#
# The pattern: we start the VM when we need cluster access, SSH in, do our
# work, then stop (deallocate) it. Deallocated means no compute charge —
# we only pay for the OS disk (~€1-2/month).
#
# "Stop" vs "Deallocate" in Azure:
#   Stop (from inside the OS): VM is still allocated, we're still charged.
#   Deallocate (from Azure portal/CLI): compute released, no charge.
#   Always use: az vm deallocate --name ... --resource-group ...
# =============================================================================

variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "project"             { type = string }
variable "environment"         { type = string }
variable "subnet_tools_id"     { type = string }
variable "ssh_public_key"      {
  type        = string
  description = <<-EOT
    Our SSH public key content (the contents of ~/.ssh/id_rsa.pub or similar).
    Pass this in via terraform.tfvars. NEVER commit a private key anywhere.
    Generate with: ssh-keygen -t ed25519 -C "voyager-jumphost"
  EOT
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
  # B1s: 1 vCPU, 1GB RAM. Enough for kubectl, psql, helm, argocd CLI.
  # B-series are "burstable", they accumulate CPU credits at idle and spend
  # them when we need them. Perfect for an intermittently-used jumphost.
}

# Public IP for the jumphost — this is the only public IP in the private cluster
resource "azurerm_public_ip" "jumphost" {
  name                = "${var.project}-${var.environment}-jumphost-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "jumphost" {
  name                = "${var.project}-${var.environment}-jumphost-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_tools_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumphost.id
    # The NIC sits in the private tools subnet but has a public IP attached.
    # Inbound SSH is controlled by the tools NSG rule we wrote in networking.
  }
}

resource "azurerm_linux_virtual_machine" "jumphost" {
  name                = "${var.project}-${var.environment}-jumphost"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = "azureuser"

  # Disable password auth entirely, SSH key only.
  # Passwords are brute-forceable. Keys are not (practically speaking).
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.jumphost.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    # Standard_LRS (HDD-backed): cheap and fine for a jumphost OS disk.
    # We'd use Premium_LRS (SSD) for anything with real I/O requirements.
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
    # Ubuntu 22.04 LTS. "latest" is acceptable for a jumphost since we're not
    # running application workloads here, just CLI tools.
  }

  # cloud-init script: installs the tools we need on first boot.
  # This runs once automatically when the VM is first created.
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - wget
      - git
      - unzip
      - jq
      - postgresql-client    # psql — for connecting to the database in Phase 4
    runcmd:
      # kubectl
      - curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      # Helm
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      # Azure CLI (for az aks get-credentials)
      - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
      # ArgoCD CLI (for Phase 5 and CI triggers in Phase 8)
      - curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
      - chmod +x /usr/local/bin/argocd
  CLOUDINIT
  )

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    role        = "jumphost"
    # Tag it with role = jumphost so it's obvious in billing reports
    # that this VM is infrastructure tooling, not an application server.
  }
}

output "jumphost_public_ip"  { value = azurerm_public_ip.jumphost.ip_address }
output "jumphost_private_ip" { value = azurerm_network_interface.jumphost.private_ip_address }
output "ssh_command" {
  value = "ssh azureuser@${azurerm_public_ip.jumphost.ip_address}"
  description = "Run this to connect. Deallocate the VM when done to stop charges."
}