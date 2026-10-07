resource_group_name = "rg-auction-prod"
location            = "eastus"

vnet_name = "vnet-auction-prod"

vnet_address_space = [
  "10.20.0.0/16"
]

workload_subnet_name   = "snet-workload"
workload_subnet_prefix = "10.20.1.0/24"

private_endpoint_subnet_name   = "snet-private-endpoints"
private_endpoint_subnet_prefix = "10.20.2.0/24"

storage_account_name = "stauctionprodsecure01"

key_vault_name = "kv-auction-prod-sec01"

identity_name = "id-auction-prod-reader"
