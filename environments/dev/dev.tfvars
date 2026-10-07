resource_group_name = "rg-auction-dev"
location            = "eastus"

vnet_name = "vnet-auction-dev"

vnet_address_space = [
  "10.10.0.0/16"
]

workload_subnet_name   = "snet-workload"
workload_subnet_prefix = "10.10.1.0/24"

private_endpoint_subnet_name   = "snet-private-endpoints"
private_endpoint_subnet_prefix = "10.10.2.0/24"
storage_account_name           = "stauctiondevsecure01"
key_vault_name                 = "kv-auction-dev-sec01"
identity_name                  = "id-auction-dev-reader"
