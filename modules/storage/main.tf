resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true

  public_network_access           = "Disabled"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_private_endpoint" "blob" {
  name                = "${var.storage_account_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                = "${var.storage_account_name}-dns-link"
  private_dns_zone_id = azurerm_private_dns_zone.blob.id
  virtual_network_id  = var.vnet_id
}
resource "azurerm_private_dns_a_record" "blob" {
  name                = var.storage_account_name
  private_dns_zone_id = azurerm_private_dns_zone.blob.id
  ttl                 = 300

  records = [
    azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
  ]
}

