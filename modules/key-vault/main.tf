resource "azurerm_key_vault" "this" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  sku_name = "standard"

  public_network_access_enabled = false
  rbac_authorization_enabled    = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

resource "azurerm_private_endpoint" "this" {
  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                = "${var.key_vault_name}-dns-link"
  private_dns_zone_id = azurerm_private_dns_zone.this.id
  virtual_network_id  = var.vnet_id
}

resource "azurerm_private_dns_a_record" "this" {
  name                = var.key_vault_name
  private_dns_zone_id = azurerm_private_dns_zone.this.id
  ttl                 = 300

  records = [
    azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
  ]
}
