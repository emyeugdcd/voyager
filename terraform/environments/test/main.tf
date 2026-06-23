# terraform/environments/shared/main.tf  (and test/, prod/)
terraform {
  backend "azurerm" {
    resource_group_name  = "voyager-tfstate-rg"
    storage_account_name = "voyagertfstateb25fa017"
    container_name       = "tfstate"
    key                  = "test/terraform.tfstate"  # "test/terraform.tfstate" etc.
  }
}