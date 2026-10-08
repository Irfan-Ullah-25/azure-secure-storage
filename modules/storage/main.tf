resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true

  public_network_access           = "Disabled"
  allow_nested_items_to_be_public = false

  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  local_user_enabled              = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  sas_policy {
    expiration_period = "7.00:00:00"
    expiration_action = "Block"
  }
}

resource "azurerm_storage_account_queue_properties" "this" {
  storage_account_id = azurerm_storage_account.this.id

  logging {
    delete                = true
    read                  = true
    write                 = true
    version               = "1.0"
    retention_policy_days = 7
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
