terraform {
  backend "azurerm" {
    resource_group_name  = "caribeshop-tfstate-rg"
    storage_account_name = "caribeshopstate12345"
    container_name       = "tfstate"
    key                  = "caribeshop.tfstate"
  }
}