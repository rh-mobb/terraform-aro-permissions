#
# objects
#
locals {
  vnet_resource_group = (var.vnet_resource_group == null || var.vnet_resource_group == "") ? var.aro_resource_group.name : var.vnet_resource_group
}

# TODO: make aro resource group name mandatory
data "azurerm_resource_group" "aro" {
  name = var.aro_resource_group.name
}

data "azurerm_resource_group" "vnet" {
  name = local.vnet_resource_group
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet
  resource_group_name = data.azurerm_resource_group.vnet.name
}

data "azurerm_network_security_group" "vnet" {
  count = (var.network_security_group == null || var.network_security_group == "") ? 0 : 1

  name                = var.network_security_group
  resource_group_name = local.vnet_resource_group
}

#
# resource provider service principal permissions
#

# permission 8: assign resource provider service principal with appropriate vnet permissions
resource "azurerm_role_assignment" "resource_provider_vnet" {
  scope              = data.azurerm_virtual_network.vnet.id
  role_definition_id = local.network_role_id
  principal_id       = data.azuread_service_principal.aro_resource_provider.object_id
}

# permission 9: assign resource provider service principal with appropriate network security group permissions
resource "azurerm_role_assignment" "resource_provider_network_security_group" {
  count = (var.network_security_group == null || var.network_security_group == "") ? 0 : 1

  scope              = data.azurerm_network_security_group.vnet[0].id
  role_definition_id = local.network_role_id
  principal_id       = data.azuread_service_principal.aro_resource_provider.object_id
}

#
# cluster service principal permissions
#

# TODO: Principals of type Application cannot validly be used in role assignments error
# # permission 1: assign cluster service principal with contributor permissions on the aro resource group
# resource "azurerm_role_assignment" "cluster_aro_resoruce_group" {
#   scope                = data.azurerm_resource_group.aro.id
#   role_definition_name = "Contributor"
#   principal_id         = var.cluster_service_principal.create ? azuread_application_registration.cluster[0].object_id : data.azuread_service_principal.cluster[0].object_id
# }

# permission 4: assign cluster service principal with appropriate network security group permissions
resource "azurerm_role_assignment" "cluster_network_security_group" {
  count = (var.network_security_group == null || var.network_security_group == "") ? 0 : 1

  scope              = data.azurerm_network_security_group.vnet[0].id
  role_definition_id = local.network_role_id
  principal_id       = var.cluster_service_principal.create ? azuread_application_registration.cluster[0].object_id : data.azuread_service_principal.cluster[0].object_id
}

output "vnet" {
  value = data.azurerm_virtual_network.vnet
}
