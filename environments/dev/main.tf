data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  vnet_name     = var.vnet_name
  address_space = var.vnet_address_space

  workload_subnet_name   = var.workload_subnet_name
  workload_subnet_prefix = var.workload_subnet_prefix

  private_endpoint_subnet_name   = var.private_endpoint_subnet_name
  private_endpoint_subnet_prefix = var.private_endpoint_subnet_prefix
}

module "storage" {
  source = "../../modules/storage"

  storage_account_name = var.storage_account_name

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  vnet_id                    = module.networking.vnet_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
}
module "identity" {
  source = "../../modules/identity"

  identity_name = var.identity_name

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_id = module.storage.storage_account_id
}

module "key_vault" {
  source = "../../modules/key-vault"

  key_vault_name = var.key_vault_name

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tenant_id = data.azurerm_client_config.current.tenant_id

  vnet_id                    = module.networking.vnet_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
}
