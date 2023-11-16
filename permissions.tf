#
# objects
#
data "azurerm_subscription" "current" {}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_network_security_group" "vnet" {
  count = (var.network_security_group == null || var.network_security_group == "") ? 0 : 1

  name                = var.network_security_group
  resource_group_name = local.network_resource_group
}

#
# cluster service principal permissions
#

# permission 1: assign cluster service principal with contributor permissions on the aro resource group
resource "azurerm_role_assignment" "cluster_aro_resource_group" {
  scope                            = data.azurerm_resource_group.aro.id
  role_definition_name             = "Contributor"
  principal_id                     = local.cluster_service_principal_object_id
  skip_service_principal_aad_check = var.cluster_service_principal.create
}

# permission 2: assign cluster service principal with appropriate network security group permissions
resource "azurerm_role_assignment" "cluster_network_security_group" {
  count = (var.network_security_group == null || var.network_security_group == "") ? 0 : 1

  scope                            = data.azurerm_network_security_group.vnet[0].id
  role_definition_id               = local.custom_network_role ? azurerm_role_definition.network[0].role_definition_resource_id : null
  role_definition_name             = local.custom_network_role ? null : "Network Contributor"
  principal_id                     = local.cluster_service_principal_object_id
  skip_service_principal_aad_check = var.cluster_service_principal.create
}

#
# installer service principal permissions
#

# permission 3: assign installer service principal with appropriate aro resource group permissions
resource "azurerm_role_assignment" "installer_aro_resource_group" {
  count = local.installer_user_set ? 0 : 1

  scope                            = data.azurerm_resource_group.aro.id
  role_definition_id               = local.custom_aro_role ? azurerm_role_definition.aro[0].role_definition_resource_id : null
  role_definition_name             = local.custom_aro_role ? null : "Contributor"
  principal_id                     = local.installer_service_principal_object_id
  skip_service_principal_aad_check = var.installer_service_principal.create
}

# permission 3: assign installer user with appropriate aro resource group permissions
resource "azurerm_role_assignment" "installer_user_aro_resource_group" {
  count = local.installer_user_set ? 1 : 0

  scope                = data.azurerm_resource_group.aro.id
  role_definition_id   = local.custom_aro_role ? azurerm_role_definition.aro[0].role_definition_resource_id : null
  role_definition_name = local.custom_aro_role ? null : "Contributor"
  principal_id         = local.installer_user_object_id
}

# permission 4: assign installer service principal reader to the network resource group if using a cli installation
resource "azurerm_role_assignment" "installer_network_resource_group" {
  count = (!local.installer_user_set && var.installation_type == "cli") ? 1 : 0

  scope                            = data.azurerm_resource_group.network.id
  role_definition_name             = "Reader"
  principal_id                     = local.installer_service_principal_object_id
  skip_service_principal_aad_check = var.installer_service_principal.create
}

# permission 4: assign installer user reader to the network resource group if using a cli installation
resource "azurerm_role_assignment" "installer_user_network_resource_group" {
  count = (local.installer_user_set && var.installation_type == "cli") ? 1 : 0

  scope                = data.azurerm_resource_group.network.id
  role_definition_name = "Reader"
  principal_id         = local.installer_user_object_id
}

# permission 5: assign installer service principal user access admin to the subscription if using a cli installation
resource "azurerm_role_assignment" "installer_subscription" {
  count = (!local.installer_user_set && var.installation_type == "cli") ? 1 : 0

  scope                            = data.azurerm_subscription.current.id
  role_definition_name             = "User Access Administrator"
  principal_id                     = local.installer_service_principal_object_id
  skip_service_principal_aad_check = var.installer_service_principal.create
}

# permission 5: assign installer user user access admin to the subscription if using a cli installation
resource "azurerm_role_assignment" "installer_user_subscription" {
  count = (local.installer_user_set && var.installation_type == "cli") ? 1 : 0

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "User Access Administrator"
  principal_id         = local.installer_user_object_id
}

# permission 6: assign installer service principal directory reader in azure ad if using a cli installation
resource "azuread_directory_role_assignment" "installer_directory" {
  count = (!local.installer_user_set && var.installation_type == "cli") ? 1 : 0

  role_id             = data.external.directory_reader_role.result.id
  principal_object_id = local.installer_service_principal_object_id
}

# permission 6: assign installer user directory reader in azure ad if using a cli installation
resource "azuread_directory_role_assignment" "installer_user_directory" {
  count = (local.installer_user_set && var.installation_type == "cli") ? 1 : 0

  role_id             = data.external.directory_reader_role.result.id
  principal_object_id = local.installer_user_object_id
}

#
# resource provider service principal permissions
#

# permission 8: assign resource provider service principal with appropriate vnet permissions
resource "azurerm_role_assignment" "resource_provider_vnet" {
  scope                = data.azurerm_virtual_network.vnet.id
  role_definition_id   = local.custom_network_role ? azurerm_role_definition.network[0].role_definition_resource_id : null
  role_definition_name = local.custom_network_role ? null : "Network Contributor"
  principal_id         = data.azuread_service_principal.aro_resource_provider.object_id
}

# permission 9: assign resource provider service principal with appropriate network security group permissions
resource "azurerm_role_assignment" "resource_provider_network_security_group" {
  count = (var.network_security_group == null || var.network_security_group == "") ? 0 : 1

  scope                = data.azurerm_network_security_group.vnet[0].id
  role_definition_id   = local.custom_network_role ? azurerm_role_definition.network[0].role_definition_resource_id : null
  role_definition_name = local.custom_network_role ? null : "Network Contributor"
  principal_id         = data.azuread_service_principal.aro_resource_provider.object_id
}
