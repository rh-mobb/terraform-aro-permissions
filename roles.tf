#
# builtin roles
#
data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

data "azurerm_role_definition" "network_contributor" {
  count = (var.minimal_network_role == null || var.minimal_network_role == "") ? 1 : 0

  name = "Network Contributor"
}

#
# custom roles
#
locals {
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
  route_table_permisisons = var.vnet_has_route_tables ? [] : [
    "Microsoft.Network/routeTables/join/action",
    "Microsoft.Network/routeTables/read",
    "Microsoft.Network/routeTables/write"
  ]

  # permissions needed by vnets with nat gateways
  nat_gateway_permissions = var.vnet_has_nat_gateways ? [] : [
    "Microsoft.Network/natGateways/join/action",
    "Microsoft.Network/natGateways/read",
    "Microsoft.Network/natGateways/write"
  ]
}

resource "azurerm_role_definition" "network" {
  count = (var.minimal_network_role == null || var.minimal_network_role == "") ? 0 : 1

  name        = "${var.cluster_name}-network"
  description = "Custom role for ARO network for cluster: ${var.cluster_name}"
  scope       = data.azurerm_virtual_network.vnet.id

  permissions {
    actions = toset(flatten(concat(local.network_permissions, local.route_table_permisisons, local.nat_gateway_permissions)))
  }

  assignable_scopes = [data.azurerm_virtual_network.vnet.id]
}

locals {
  network_role_id = (var.minimal_network_role == null || var.minimal_network_role == "") ? data.azurerm_role_definition.network_contributor[0].id : azurerm_role_definition.network[0].role_definition_resource_id
}
