locals {
  vnet_resource_group = (var.vnet_resource_group == null || var.vnet_resource_group == "") ? var.aro_resource_group.name : var.vnet_resource_group
}

data "azurerm_resource_group" "vnet" {
  name = local.vnet_resource_group
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet
  resource_group_name = data.azurerm_resource_group.vnet.name
}
