locals {
  network_resource_group = (var.vnet_resource_group == null || var.vnet_resource_group == "") ? var.aro_resource_group.name : var.vnet_resource_group
}

# TODO: make aro resource group name mandatory
data "azurerm_resource_group" "aro" {
  name = var.aro_resource_group.name
}

data "azurerm_resource_group" "network" {
  name = local.network_resource_group
}
