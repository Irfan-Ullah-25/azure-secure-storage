terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-dev"
    storage_account_name = "tfstateauctiondev"
    container_name       = "tfstate"
    key                  = "azure-secure-storage-prod.tfstate"
  }
}
