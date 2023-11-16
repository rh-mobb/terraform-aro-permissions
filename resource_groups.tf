locals {
  network_resource_group = (var.vnet_resource_group == null || var.vnet_resource_group == "") ? var.aro_resource_group.name : var.vnet_resource_group
}

data "azurerm_resource_group" "aro" {
  count = var.aro_resource_group.create ? 0 : 1

  name = var.aro_resource_group.name
}

data "azurerm_resource_group" "network" {
  name = local.network_resource_group
}

# NOTE: create the resource group if it is requested.  this assumes vnet is in the same location as this resource group.
resource "azurerm_resource_group" "aro" {
  count = var.aro_resource_group.create ? 1 : 0

  name     = var.aro_resource_group.name
  location = data.azurerm_virtual_network.vnet.location
}

# NOTE: we do this to ensure order of operations an validate the resource group exists if we are not creating
locals {
  aro_resource_group = var.aro_resource_group.create ? azurerm_resource_group.aro[0] : data.azurerm_resource_group.aro[0]
}
