#
# minimal network role
#
locals {
  custom_network_role = (var.minimal_network_role != null && var.minimal_network_role != "")

  # base permissions needed by all
  network_permissions = [
    "Microsoft.Network/virtualNetworks/join/action",
    "Microsoft.Network/virtualNetworks/read",
    "Microsoft.Network/virtualNetworks/write",
    "Microsoft.Network/virtualNetworks/subnets/join/action",
    "Microsoft.Network/virtualNetworks/subnets/read",
    "Microsoft.Network/virtualNetworks/subnets/write",
    "Microsoft.Network/networkSecurityGroups/join/action"
  ]

  # permissions needed by vnets with route tables
  route_table_permissions = var.vnet_has_route_tables ? [
    "Microsoft.Network/routeTables/join/action",
    "Microsoft.Network/routeTables/read",
    "Microsoft.Network/routeTables/write"
  ] : []

  # permissions needed by vnets with nat gateways
  nat_gateway_permissions = var.vnet_has_nat_gateways ? [
    "Microsoft.Network/natGateways/join/action",
    "Microsoft.Network/natGateways/read",
    "Microsoft.Network/natGateways/write"
  ] : []
}

resource "azurerm_role_definition" "network" {
  count = local.custom_network_role ? 1 : 0

  name        = "${var.cluster_name}-network"
  description = "Custom role for ARO network for cluster: ${var.cluster_name}"
  scope       = data.azurerm_virtual_network.vnet.id

  permissions {
    actions = toset(flatten(concat(local.network_permissions, local.route_table_permissions, local.nat_gateway_permissions)))
  }

  assignable_scopes = [data.azurerm_virtual_network.vnet.id]
}

#
# minimal aro role
#
locals {
  custom_aro_role = (var.minimal_aro_role != null && var.minimal_aro_role != "")

  aro_permissions = [
    "Microsoft.RedHatOpenShift/openShiftClusters/read",
    "Microsoft.RedHatOpenShift/openShiftClusters/write",
    "Microsoft.RedHatOpenShift/openShiftClusters/delete",
    "Microsoft.RedHatOpenShift/openShiftClusters/listCredentials/action",
    "Microsoft.RedHatOpenShift/openShiftClusters/listAdminCredentials/action"
  ]
}

resource "azurerm_role_definition" "aro" {
  count = local.custom_aro_role ? 1 : 0

  name        = "${var.cluster_name}-aro"
  description = "Custom role for ARO for cluster: ${var.cluster_name}"
  scope       = local.aro_resource_group.id

  permissions {
    actions = local.aro_permissions
  }

  assignable_scopes = [local.aro_resource_group.id]
}

#
# directory reader role
#   NOTE: we do this only because using the azapi provider it is not obvious how to accomplish this and TF does not have a direct role
#         for azure ad roles
#   TODO: fix this
#
locals {
  directory_reader_role_command = <<-EOT
ID=$(az rest --method GET --url https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions | jq -r '.value[] | select(.displayName == "Directory Readers") | .templateId') && echo "{\"id\":\"$ID\"}"
EOT
}

data "external" "directory_reader_role" {
  program = [
    "sh",
    "-c",
    local.directory_reader_role_command
  ]
}
