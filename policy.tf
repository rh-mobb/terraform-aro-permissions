locals {
  apply_route_table_policy = var.apply_route_table_policy && length(var.route_tables) > 0
  apply_nat_gateway_policy = var.apply_nat_gateway_policy && length(var.nat_gateways) > 0
  apply_nsg_policy         = var.apply_nsg_policy && (var.network_security_group != null && var.network_security_group != "")
}

#
# vnet
#
locals {
  deny_vnet_policy_name = "aro-${var.cluster_name}-deny-vnet"
}

resource "azurerm_policy_definition" "deny_vnet" {
  count = var.apply_vnet_policy ? 1 : 0

  name         = local.deny_vnet_policy_name
  display_name = local.deny_vnet_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/virtualNetworks"
        },
        {
          "field" : "name",
          "equals" : var.vnet
        }
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_vnet_delete" {
  count = var.apply_vnet_policy ? 1 : 0

  name         = "${local.deny_vnet_policy_name}-delete"
  display_name = "${local.deny_vnet_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/virtualNetworks"
        },
        {
          "field" : "name",
          "equals" : var.vnet
        }
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_set_definition" "deny_vnet_initiative" {
  count = var.apply_vnet_policy ? 1 : 0

  name         = "${local.deny_vnet_policy_name}-initiative"
  display_name = "${local.deny_vnet_policy_name}-initiative"
  policy_type  = "Custom"

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_vnet[0].id
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_vnet_delete[0].id
  }
}

resource "azurerm_resource_group_policy_assignment" "deny_vnet_assignment" {
  count = var.apply_vnet_policy ? 1 : 0

  name                 = "${local.deny_vnet_policy_name}-assignment"
  display_name         = "${local.deny_vnet_policy_name}-assignment"
  policy_definition_id = azurerm_policy_set_definition.deny_vnet_initiative[0].id
  resource_group_id    = local.network_resource_group_id

  non_compliance_message {
    content = "Denied via ${local.deny_vnet_policy_name}-assignment"
  }
}

#
# subnet
#
# TODO: uncomment this only when PR https://github.com/Azure/ARO-RP/pull/4087 is
#       merged and released.  Currently, the subnet/write permission is still 
#       needed as the resource provider does a CreateOrUpdate regardless of
#       correct subnet configuration, which needs subnet/write.  Once the above
#       PR is merged and active, we can uncomment the below.
#
# locals {
#   deny_subnet_policy_name = "aro-${var.cluster_name}-deny-subnet"
# }
#
# resource "azurerm_policy_definition" "deny_subnet" {
#   count = var.apply_subnet_policy ? 1 : 0
#
#   name         = local.deny_subnet_policy_name
#   display_name = local.deny_subnet_policy_name
#   policy_type  = "Custom"
#   mode         = "All"
#
#   policy_rule = jsonencode({
#     "if" : {
#       "allOf": [
#         {
#           "field" : "type",
#           "equals" : "Microsoft.Network/virtualNetworks/subnets"
#         },
#         {
#           "field" : "id",
#           "contains" : "${local.network_resource_group_id}/providers/Microsoft.Network/virtualNetworks/${var.vnet}"
#         }
#       ]
#     },
#     "then" : {
#       "effect" : "deny"
#     }
#   })
# }
#
# resource "azurerm_policy_definition" "deny_subnet_delete" {
#   count = var.apply_subnet_policy ? 1 : 0

#   name         = "${local.deny_subnet_policy_name}-delete"
#   display_name = "${local.deny_subnet_policy_name}-delete"
#   policy_type  = "Custom"
#   mode         = "All"

#   policy_rule = jsonencode({
#     "if" : {
#       "allOf": [
#         {
#           "field" : "type",
#           "equals" : "Microsoft.Network/virtualNetworks/subnets"
#         },
#         {
#           "field" : "id",
#           "contains" : "${local.network_resource_group_id}/providers/Microsoft.Network/virtualNetworks/${var.vnet}"
#         }
#       ]
#     },
#     "then" : {
#       "effect" : "denyAction",
#       "details" : {
#         "actionNames" : [
#           "delete"
#         ]
#       }
#     }
#   })
# }
#
# resource "azurerm_policy_set_definition" "deny_subnet_initiative" {
#   count = var.apply_subnet_policy ? 1 : 0
#
#   name         = "${local.deny_subnet_policy_name}-initiative"
#   display_name = "${local.deny_subnet_policy_name}-initiative"
#   policy_type  = "Custom"
#
#   policy_definition_reference {
#     policy_definition_id = azurerm_policy_definition.deny_subnet[0].id
#   }
#
#   policy_definition_reference {
#     policy_definition_id = azurerm_policy_definition.deny_subnet_delete[0].id
#   }
# }
#
# resource "azurerm_resource_group_policy_assignment" "deny_subnet_assignment" {
#   count = var.apply_subnet_policy ? 1 : 0
#
#   name                 = "${local.deny_subnet_policy_name}-assignment"
#   display_name         = "${local.deny_subnet_policy_name}-assignment"
#   policy_definition_id = azurerm_policy_set_definition.deny_subnet_initiative[0].id
#   resource_group_id    = local.network_resource_group_id
#
#   non_compliance_message {
#     content = "Denied via ${local.deny_subnet_policy_name}-assignment"
#   }
# }

#
# route table
#
locals {
  deny_route_table_policy_name = "aro-${var.cluster_name}-deny-route-table"
}

resource "azurerm_policy_definition" "deny_route_table" {
  count = local.apply_route_table_policy ? 1 : 0

  name         = local.deny_route_table_policy_name
  display_name = local.deny_route_table_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/routeTables"
        },
        {
          "anyOf" : [for route_table in var.route_tables : { "field" : "name", "equals" : route_table }]
        }
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_route_table_delete" {
  count = local.apply_route_table_policy ? 1 : 0

  name         = "${local.deny_route_table_policy_name}-delete"
  display_name = "${local.deny_route_table_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/routeTables"
        },
        {
          "anyOf" : [for route_table in var.route_tables : { "field" : "name", "equals" : route_table }]
        }
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_set_definition" "deny_route_table_initiative" {
  count = local.apply_route_table_policy ? 1 : 0

  name         = "${local.deny_route_table_policy_name}-initiative"
  display_name = "${local.deny_route_table_policy_name}-initiative"
  policy_type  = "Custom"

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_route_table[0].id
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_route_table_delete[0].id
  }
}

resource "azurerm_resource_group_policy_assignment" "deny_route_table_assignment" {
  count = var.apply_route_table_policy ? 1 : 0

  name                 = "${local.deny_route_table_policy_name}-assignment"
  display_name         = "${local.deny_route_table_policy_name}-assignment"
  policy_definition_id = azurerm_policy_set_definition.deny_route_table_initiative[0].id
  resource_group_id    = local.network_resource_group_id

  non_compliance_message {
    content = "Denied via ${local.deny_route_table_policy_name}-assignment"
  }
}

#
# nat gateway
#
locals {
  deny_nat_gateway_policy_name = "aro-${var.cluster_name}-deny-nat-gateway"
}

resource "azurerm_policy_definition" "deny_nat_gateway" {
  count = local.apply_nat_gateway_policy ? 1 : 0

  name         = local.deny_nat_gateway_policy_name
  display_name = local.deny_nat_gateway_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/natGateways"
        },
        {
          "anyOf" : [for nat_gateway in var.nat_gateways : { "field" : "name", "equals" : nat_gateway }]
        }
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_nat_gateway_delete" {
  count = local.apply_nat_gateway_policy ? 1 : 0

  name         = "${local.deny_nat_gateway_policy_name}-delete"
  display_name = "${local.deny_nat_gateway_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/natGateways"
        },
        {
          "anyOf" : [for nat_gateway in var.nat_gateways : { "field" : "name", "equals" : nat_gateway }]
        }
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_set_definition" "deny_nat_gateway_initiative" {
  count = local.apply_nat_gateway_policy ? 1 : 0

  name         = "${local.deny_nat_gateway_policy_name}-initiative"
  display_name = "${local.deny_nat_gateway_policy_name}-initiative"
  policy_type  = "Custom"

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_nat_gateway[0].id
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_nat_gateway_delete[0].id
  }
}

resource "azurerm_resource_group_policy_assignment" "deny_nat_gateway_assignment" {
  count = local.apply_nat_gateway_policy ? 1 : 0

  name                 = "${local.deny_nat_gateway_policy_name}-assignment"
  display_name         = "${local.deny_nat_gateway_policy_name}-assignment"
  policy_definition_id = azurerm_policy_set_definition.deny_nat_gateway_initiative[0].id
  resource_group_id    = local.network_resource_group_id

  non_compliance_message {
    content = "Denied via ${local.deny_nat_gateway_policy_name}-assignment"
  }
}

#
# nsg
#
locals {
  deny_nsg_policy_name = "aro-${var.cluster_name}-deny-nsg"
}

resource "azurerm_policy_definition" "deny_nsg" {
  count = local.apply_nsg_policy ? 1 : 0

  name         = local.deny_nsg_policy_name
  display_name = local.deny_nsg_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/networkSecurityGroups"
        },
        {
          "field" : "name",
          "equals" : var.network_security_group
        }
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_nsg_delete" {
  count = local.apply_nsg_policy ? 1 : 0

  name         = "${local.deny_nsg_policy_name}-delete"
  display_name = "${local.deny_nsg_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/natGateways"
        },
        {
          "field" : "name",
          "equals" : var.network_security_group
        }
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_set_definition" "deny_nsg_initiative" {
  count = local.apply_nsg_policy ? 1 : 0

  name         = "${local.deny_nsg_policy_name}-initiative"
  display_name = "${local.deny_nsg_policy_name}-initiative"
  policy_type  = "Custom"

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_nsg[0].id
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_nsg_delete[0].id
  }
}

resource "azurerm_resource_group_policy_assignment" "deny_nsg_assignment" {
  count = local.apply_nsg_policy ? 1 : 0

  name                 = "${local.deny_nsg_policy_name}-assignment"
  display_name         = "${local.deny_nsg_policy_name}-assignment"
  policy_definition_id = azurerm_policy_set_definition.deny_nsg_initiative[0].id
  resource_group_id    = local.network_resource_group_id

  non_compliance_message {
    content = "Denied via ${local.deny_nsg_policy_name}-assignment"
  }
}

#
# managed resource group restrictions
#
locals {
  has_managed_resource_group = var.managed_resource_group != "" && var.managed_resource_group != null

  apply_dns_policy         = var.apply_dns_policy && local.has_managed_resource_group
  apply_private_dns_policy = var.apply_private_dns_policy && local.has_managed_resource_group
  apply_public_ip_policy   = var.apply_public_ip_policy && local.has_managed_resource_group
  apply_managed_policies   = local.apply_dns_policy || local.apply_private_dns_policy || local.apply_public_ip_policy

  deny_dns_policy_name              = "aro-${var.cluster_name}-deny-dns"
  deny_dns_zone_policy_name         = "aro-${var.cluster_name}-deny-dns-zone"
  deny_private_dns_policy_name      = "aro-${var.cluster_name}-deny-private-dns"
  deny_private_dns_zone_policy_name = "aro-${var.cluster_name}-deny-private-dns-zone"
  deny_public_ip_policy_name        = "aro-${var.cluster_name}-deny-public-ip"
}

resource "azurerm_policy_definition" "deny_dns" {
  count = local.apply_dns_policy ? 1 : 0

  name         = local.deny_dns_policy_name
  display_name = local.deny_dns_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/dnsZones/A"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_dns_delete" {
  count = local.apply_dns_policy ? 1 : 0

  name         = "${local.deny_dns_policy_name}-delete"
  display_name = "${local.deny_dns_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/dnsZones/A"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_definition" "deny_dns_zone" {
  count = local.apply_dns_policy ? 1 : 0

  name         = local.deny_dns_zone_policy_name
  display_name = local.deny_dns_zone_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/dnsZones"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_dns_zone_delete" {
  count = local.apply_dns_policy ? 1 : 0

  name         = "${local.deny_dns_zone_policy_name}-delete"
  display_name = "${local.deny_dns_zone_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/dnsZones/A"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_definition" "deny_private_dns" {
  count = local.apply_private_dns_policy ? 1 : 0

  name         = local.deny_private_dns_policy_name
  display_name = local.deny_private_dns_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/privateDnsZones/A"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_private_dns_delete" {
  count = local.apply_private_dns_policy ? 1 : 0

  name         = "${local.deny_private_dns_policy_name}-delete"
  display_name = "${local.deny_private_dns_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/privateDnsZones/A"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_definition" "deny_private_dns_zone" {
  count = local.apply_private_dns_policy ? 1 : 0

  name         = local.deny_private_dns_zone_policy_name
  display_name = local.deny_private_dns_zone_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/privateDnsZones"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_private_dns_zone_delete" {
  count = local.apply_private_dns_policy ? 1 : 0

  name         = "${local.deny_private_dns_zone_policy_name}-delete"
  display_name = "${local.deny_private_dns_zone_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/privateDnsZones"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_definition" "deny_public_ip" {
  count = local.apply_public_ip_policy ? 1 : 0

  name         = local.deny_public_ip_policy_name
  display_name = local.deny_public_ip_policy_name
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/publicIPAddresses"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_public_ip_delete" {
  count = local.apply_public_ip_policy ? 1 : 0

  name         = "${local.deny_public_ip_policy_name}-delete"
  display_name = "${local.deny_public_ip_policy_name}-delete"
  policy_type  = "Custom"
  mode         = "All"

  policy_rule = jsonencode({
    "if" : {
      "allOf" : [
        {
          "field" : "type",
          "equals" : "Microsoft.Network/publicIPAddresses"
        },
        {
          "value" : "[resourceGroup().name]",
          "equals" : var.managed_resource_group
        },
      ]
    },
    "then" : {
      "effect" : "denyAction",
      "details" : {
        "actionNames" : [
          "delete"
        ]
      }
    }
  })
}

resource "azurerm_policy_set_definition" "deny_managed_initiative" {
  count = local.apply_managed_policies ? 1 : 0

  name         = "aro-${var.cluster_name}-deny-managed-initiative"
  display_name = "aro-${var.cluster_name}-deny-managed-initiative"
  policy_type  = "Custom"

  dynamic "policy_definition_reference" {
    for_each = {
      deny_dns                     = local.apply_dns_policy ? azurerm_policy_definition.deny_dns[0].id : null
      deny_dns_delete              = local.apply_dns_policy ? azurerm_policy_definition.deny_dns_delete[0].id : null
      deny_dns_zone                = local.apply_dns_policy ? azurerm_policy_definition.deny_dns_zone[0].id : null
      deny_dns_zone_delete         = local.apply_dns_policy ? azurerm_policy_definition.deny_dns_zone_delete[0].id : null
      deny_private_dns             = local.apply_private_dns_policy ? azurerm_policy_definition.deny_private_dns[0].id : null
      deny_private_dns_delete      = local.apply_private_dns_policy ? azurerm_policy_definition.deny_private_dns_delete[0].id : null
      deny_private_dns_zone        = local.apply_private_dns_policy ? azurerm_policy_definition.deny_private_dns_zone[0].id : null
      deny_private_dns_zone_delete = local.apply_private_dns_policy ? azurerm_policy_definition.deny_private_dns_zone_delete[0].id : null
      deny_public_ip               = local.apply_public_ip_policy ? azurerm_policy_definition.deny_public_ip[0].id : null
      deny_public_ip_delete        = local.apply_public_ip_policy ? azurerm_policy_definition.deny_public_ip_delete[0].id : null
    }

    content {
      policy_definition_id = policy_definition_reference.value
    }
  }
}

resource "azurerm_subscription_policy_assignment" "deny_managed_assignment" {
  count = local.apply_managed_policies ? 1 : 0

  name                 = "aro-${var.cluster_name}-deny-managed-assignment"
  display_name         = "aro-${var.cluster_name}-deny-managed-assignment"
  policy_definition_id = azurerm_policy_set_definition.deny_managed_initiative[0].id
  subscription_id      = "/subscriptions/${var.subscription_id}"

  non_compliance_message {
    content = "Denied via aro-${var.cluster_name}-deny-managed-assignment"
  }
}
