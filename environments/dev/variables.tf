variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "workload_subnet_name" {
  type = string
}

variable "workload_subnet_prefix" {
  type = string
}

variable "private_endpoint_subnet_name" {
  type = string
}

variable "private_endpoint_subnet_prefix" {
  type = string

}
variable "storage_account_name" {
  type = string
}
variable "key_vault_name" {
  type = string
}
variable "identity_name" {
  type = string
}
