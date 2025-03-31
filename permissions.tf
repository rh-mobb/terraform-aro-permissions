#
# object ids
#
locals {
  # network object ids
  vnet_id                   = "${local.network_resource_group_id}/providers/Microsoft.Network/virtualNetworks/${var.vnet}"
  subnet_ids                = [for s in var.subnets : "${local.vnet_id}/subnets/${s}"]
  network_security_group_id = (var.network_security_group == null || var.network_security_group == "") ? null : "${local.network_resource_group_id}/providers/Microsoft.Network/networkSecurityGroups/${var.network_security_group}"
  route_table_ids = length(var.route_tables) == 0 || var.route_tables == null ? [] : [
    for route_table in var.route_tables : "${local.network_resource_group_id}/providers/Microsoft.Network/routeTables/${route_table}"
  ]
  nat_gateway_ids = length(var.nat_gateways) == 0 || var.nat_gateways == null ? [] : [
    for nat_gateway in var.nat_gateways : "${local.network_resource_group_id}/providers/Microsoft.Network/natGateways/${nat_gateway}"
  ]

  # other object ids
  disk_encryption_set_id = (var.disk_encryption_set == null || var.disk_encryption_set == "") ? null : "${local.aro_resource_group_id}/providers/Microsoft.Compute/diskEncryptionSets/${var.disk_encryption_set}"
}

#
# cluster service principal and managed identity permissions
#
locals {
  vnet_cluster_identities                   = var.enable_managed_identities ? local.vnet_managed_identity_ids : [local.cluster_service_principal_object_id]
  subnet_cluster_identities                 = var.enable_managed_identities ? local.subnet_managed_identity_ids : [local.cluster_service_principal_object_id]
  route_table_cluster_identities            = var.enable_managed_identities ? local.route_table_managed_identity_ids : [local.cluster_service_principal_object_id]
  nat_gateway_cluster_identities            = var.enable_managed_identities ? local.nat_gateway_managed_identity_ids : [local.cluster_service_principal_object_id]
  network_security_group_cluster_identities = var.enable_managed_identities ? local.network_security_group_managed_identity_ids : [local.cluster_service_principal_object_id]
  federated_credential_cluster_identities   = var.enable_managed_identities ? local.federated_credential_managed_identity_ids : []

  # skip the aad check if we create the service principal to avoid a condition
  # where AAD is not fully synced when we create the role assignment
  skip_aad_check = var.enable_managed_identities ? true : var.cluster_service_principal.create
}

# permission 1: assign cluster identity with appropriate vnet permissions
resource "azurerm_role_assignment" "cluster_vnet" {
  count = length(local.vnet_cluster_identities)

  scope                            = local.vnet_id
  role_definition_id               = local.has_custom_network_role ? azurerm_role_definition.network[0].role_definition_resource_id : null
  role_definition_name             = local.has_custom_network_role ? null : "Network Contributor"
  principal_id                     = local.vnet_cluster_identities[count.index]
  skip_service_principal_aad_check = local.skip_aad_check
}

output "debug_subnet_ids" {
  value = local.subnet_ids
}

output "debug_subnet_cluster_identities" {
  value = local.subnet_cluster_identities
}

locals {
  subnet_identity_map = length(local.subnet_ids) > 0 ? flatten(
    [
      for subnet in local.subnet_ids : [
        for identity in local.subnet_cluster_identities :
        {
          subnet_id   = subnet
          identity_id = identity
        }
      ]
    ]
  ) : []
}

resource "azurerm_role_assignment" "cluster_vnet_subnets" {
  count = length(local.subnet_identity_map)

  scope                            = local.subnet_identity_map[count.index].subnet_id
  role_definition_id               = local.has_custom_network_role ? azurerm_role_definition.subnet[0].role_definition_resource_id : null
  role_definition_name             = local.has_custom_network_role ? null : "Network Contributor"
  principal_id                     = local.subnet_identity_map[count.index].identity_id
  skip_service_principal_aad_check = local.skip_aad_check
}

locals {
  route_table_identity_map = length(var.route_tables) > 0 ? flatten(
    [
      for role in azurerm_role_definition.network_route_tables : [
        for identity in local.route_table_cluster_identities :
        {
          route_table_id = role.scope
          identity_id    = identity
          role_id        = role.role_definition_resource_id
        }
      ]
    ]...
  ) : []
}

resource "azurerm_role_assignment" "cluster_route_tables" {
  count = length(local.route_table_identity_map)

  scope                            = local.route_table_identity_map[count.index].route_table_id
  role_definition_id               = local.has_custom_network_role ? local.route_table_identity_map[count.index].role_id : null
  role_definition_name             = local.has_custom_network_role ? null : "Network Contributor"
  principal_id                     = local.route_table_identity_map[count.index].identity_id
  skip_service_principal_aad_check = local.skip_aad_check
}

locals {
  nat_gateway_identity_map = length(var.nat_gateways) > 0 ? flatten(
    [
      for role in azurerm_role_definition.network_nat_gateways : [
        for identity in local.nat_gateway_cluster_identities :
        {
          nat_gateway_id = role.scope
          identity_id    = identity
          role_id        = role.role_definition_resource_id
        }
      ]
    ]...
  ) : []
}

resource "azurerm_role_assignment" "cluster_nat_gateways" {
  count = length(local.nat_gateway_identity_map)

  scope                            = local.nat_gateway_identity_map[count.index].nat_gateway_id
  role_definition_id               = local.has_custom_network_role ? local.nat_gateway_identity_map[count.index].role_id : null
  role_definition_name             = local.has_custom_network_role ? null : "Network Contributor"
  principal_id                     = local.nat_gateway_identity_map[count.index].identity_id
  skip_service_principal_aad_check = local.skip_aad_check
}

# permission 2: assign cluster identity with appropriate network security group permissions
resource "azurerm_role_assignment" "cluster_network_security_group" {
  count = (var.network_security_group != null && var.network_security_group != "") ? length(local.network_security_group_cluster_identities) : 0

  scope                            = local.network_security_group_id
  role_definition_id               = local.has_custom_network_role ? azurerm_role_definition.network_network_security_group[0].role_definition_resource_id : null
  role_definition_name             = local.has_custom_network_role ? null : "Network Contributor"
  principal_id                     = local.network_security_group_cluster_identities[count.index]
  skip_service_principal_aad_check = local.skip_aad_check
}

# permission 3: assign cluster identity with contributor permissions on the aro resource group
resource "azurerm_role_assignment" "cluster_aro_resource_group" {
  count = var.enable_managed_identities ? 0 : 1

  scope                            = local.aro_resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = local.cluster_service_principal_object_id
  skip_service_principal_aad_check = local.skip_aad_check
}

# permission 4: assign cluster identity with appropriate disk encryption set permissions
resource "azurerm_role_assignment" "cluster_disk_encryption_set" {
  count = local.has_custom_des_role ? 1 : 0

  scope                            = local.disk_encryption_set_id
  role_definition_id               = local.has_custom_des_role ? azurerm_role_definition.des[0].role_definition_resource_id : null
  principal_id                     = local.cluster_service_principal_object_id
  skip_service_principal_aad_check = local.skip_aad_check
}

# future permission(mi/wi): assign cluster identity with appropriate federated credential permissions
resource "azurerm_role_assignment" "cluster_federated_credentials" {
  count = length(local.federated_credential_cluster_identities)

  scope                            = local.aro_resource_group_id
  role_definition_name             = "Azure Red Hat OpenShift Federated Credential"
  principal_id                     = local.federated_credential_cluster_identities[count.index]
  skip_service_principal_aad_check = local.skip_aad_check
}

#
# installer service principal permissions
#

# permission 5: assign installer identity with appropriate aro resource group permissions
resource "azurerm_role_assignment" "installer_aro_resource_group" {
  scope                            = local.aro_resource_group_id
  role_definition_id               = local.has_custom_aro_role ? azurerm_role_definition.aro[0].role_definition_resource_id : null
  role_definition_name             = local.has_custom_aro_role ? null : "Contributor"
  principal_id                     = local.installer_object_id
  skip_service_principal_aad_check = var.installer_service_principal.create
}

# permission 6: assign installer identity reader to the network resource group if using a cli installation
resource "azurerm_role_assignment" "installer_network_resource_group" {
  count = var.installation_type == "cli" ? 1 : 0

  scope                            = local.network_resource_group_id
  role_definition_name             = "Reader"
  principal_id                     = local.installer_object_id
  skip_service_principal_aad_check = var.installer_service_principal.create
}

# permission 7: assign installer identity user access admin to the subscription if using a cli installation
resource "azurerm_role_assignment" "installer_subscription" {
  count = var.installation_type == "cli" ? 1 : 0

  scope                            = "/subscriptions/${var.subscription_id}"
  role_definition_name             = "User Access Administrator"
  principal_id                     = local.installer_object_id
  skip_service_principal_aad_check = var.installer_service_principal.create
}

# permission 8: assign installer identity directory reader in azure ad if using a cli installation
# NOTE:
#   - The role ID for this role definition will always be 88d8e3e3-8f55-4a1e-953a-9b9898b8876b
#   - https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference?toc=%2Fgraph%2Ftoc.json#directory-readers
locals {
  directory_reader_role_id = "88d8e3e3-8f55-4a1e-953a-9b9898b8876b"
}

resource "azuread_directory_role_assignment" "installer_directory" {
  count = var.installation_type == "cli" ? 1 : 0

  role_id             = local.directory_reader_role_id
  principal_object_id = local.installer_object_id
}

# permission 9: assign installer identity with appropriate vnet permissions
resource "azurerm_role_assignment" "installer_vnet" {
  count = var.installation_type == "cli" ? 1 : 0

  scope                = local.vnet_id
  role_definition_id   = local.has_custom_network_role ? azurerm_role_definition.network[0].role_definition_resource_id : null
  role_definition_name = local.has_custom_network_role ? null : "Network Contributor"
  principal_id         = local.installer_object_id
}

#
# resource provider service principal permissions
#

# permission 10: assign resource provider service principal with appropriate vnet permissions
resource "azurerm_role_assignment" "resource_provider_vnet" {
  scope                = local.vnet_id
  role_definition_id   = local.has_custom_network_role ? azurerm_role_definition.network[0].role_definition_resource_id : null
  role_definition_name = local.has_custom_network_role ? null : "Network Contributor"
  principal_id         = data.azuread_service_principal.aro_resource_provider.object_id
}

resource "azurerm_role_assignment" "resource_provider_route_tables" {
  count = length(local.route_table_ids)

  scope                = local.route_table_ids[count.index]
  role_definition_id   = local.has_custom_network_role ? azurerm_role_definition.network_route_tables[count.index].role_definition_resource_id : null
  role_definition_name = local.has_custom_network_role ? null : "Network Contributor"
  principal_id         = data.azuread_service_principal.aro_resource_provider.object_id
}

resource "azurerm_role_assignment" "resource_provider_nat_gateways" {
  count = length(local.nat_gateway_ids)

  scope                = local.nat_gateway_ids[count.index]
  role_definition_id   = local.has_custom_network_role ? azurerm_role_definition.network_nat_gateways[0].role_definition_resource_id : null
  role_definition_name = local.has_custom_network_role ? null : "Network Contributor"
  principal_id         = data.azuread_service_principal.aro_resource_provider.object_id
}

# permission 11: assign resource provider service principal with appropriate network security group permissions
resource "azurerm_role_assignment" "resource_provider_network_security_group" {
  count = (var.network_security_group == null || var.network_security_group == "") ? 0 : 1

  scope                = local.network_security_group_id
  role_definition_id   = local.has_custom_network_role ? azurerm_role_definition.network_network_security_group[0].role_definition_resource_id : null
  role_definition_name = local.has_custom_network_role ? null : "Network Contributor"
  principal_id         = data.azuread_service_principal.aro_resource_provider.object_id
}

# permission 12: assign resource provider service principal with appropriate disk encryption set permissions
resource "azurerm_role_assignment" "resource_provider_disk_encryption_set" {
  count = local.has_custom_des_role ? 1 : 0

  scope              = local.disk_encryption_set_id
  role_definition_id = local.has_custom_des_role ? azurerm_role_definition.des[0].role_definition_resource_id : null
  principal_id       = data.azuread_service_principal.aro_resource_provider.object_id
}
