#
# cluster service principal
#
locals {
  cluster_service_principal_name   = (var.cluster_service_principal.name == "") || (var.cluster_service_principal.name == null) ? "${var.cluster_name}-cluster" : var.cluster_service_principal.name
  cluster_service_principal_create = var.cluster_service_principal.create && !var.enable_managed_identities
}

# NOTE: pull the existing service principal if one was passed and we are not creating it
data "azuread_service_principal" "cluster" {
  count = local.cluster_service_principal_create ? 0 : var.enable_managed_identities ? 0 : 1

  display_name = local.cluster_service_principal_name
}

# NOTE: create the service principal if creation is requested
resource "azuread_application" "cluster" {
  count = local.cluster_service_principal_create ? 1 : 0

  display_name = local.cluster_service_principal_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "cluster" {
  count = local.cluster_service_principal_create ? 1 : 0

  display_name   = local.cluster_service_principal_name
  application_id = local.cluster_service_principal_app_id
}

resource "azuread_service_principal" "cluster" {
  count = local.cluster_service_principal_create ? 1 : 0

  client_id = local.cluster_service_principal_client_id
  owners    = [data.azuread_client_config.current.object_id]
}

locals {
  cluster_service_principal_object_id     = local.cluster_service_principal_create ? azuread_service_principal.cluster[0].object_id : var.enable_managed_identities ? null : data.azuread_service_principal.cluster[0].object_id
  cluster_service_principal_client_id     = local.cluster_service_principal_create ? azuread_application.cluster[0].client_id : null
  cluster_service_principal_app_id        = local.cluster_service_principal_create ? azuread_application.cluster[0].id : null
  cluster_service_principal_client_secret = local.cluster_service_principal_create ? azuread_application_password.cluster[0].value : null
}

#
# installer service principal
#
locals {
  installer_user_set                 = (var.installer_user != "") && (var.installer_user != null)
  installer_service_principal_name   = (var.installer_service_principal.name == "") || (var.installer_service_principal.name == null) ? "${var.cluster_name}-installer" : var.installer_service_principal.name
  installer_service_principal_create = var.installer_service_principal.create
}

# NOTE: pull the existing service principal if one was passed and we are not creating it and the user is not set
data "azuread_service_principal" "installer" {
  count = local.installer_user_set ? 0 : (local.installer_service_principal_create ? 0 : 1)

  display_name = local.installer_service_principal_name
}

resource "azuread_application" "installer" {
  count = local.installer_user_set ? 0 : (local.installer_service_principal_create ? 1 : 0)

  display_name = local.installer_service_principal_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "installer" {
  count = local.installer_user_set ? 0 : (local.installer_service_principal_create ? 1 : 0)

  display_name   = local.installer_service_principal_name
  application_id = local.installer_service_principal_app_id
}

resource "azuread_service_principal" "installer" {
  count = local.installer_user_set ? 0 : (local.installer_service_principal_create ? 1 : 0)

  client_id = local.installer_service_principal_client_id
  owners    = [data.azuread_client_config.current.object_id]
}

data "azuread_user" "installer" {
  count = local.installer_user_set ? 1 : 0

  user_principal_name = var.installer_user
}

locals {
  installer_service_principal_object_id     = local.installer_user_set ? null : (local.installer_service_principal_create ? azuread_service_principal.installer[0].object_id : data.azuread_service_principal.installer[0].object_id)
  installer_user_object_id                  = local.installer_user_set ? data.azuread_user.installer[0].object_id : null
  installer_object_id                       = local.installer_user_set ? local.installer_user_object_id : local.installer_service_principal_object_id
  installer_service_principal_app_id        = local.installer_service_principal_create ? azuread_application.installer[0].id : null
  installer_service_principal_client_id     = local.installer_service_principal_create ? azuread_application.installer[0].client_id : null
  installer_service_principal_client_secret = local.installer_service_principal_create ? azuread_application_password.installer[0].value : null
}

#
# aro resource provider service principal
#   NOTE: this is created by the 'az provider register' commands and will be pre-existing once that command has been run.
#
data "azuread_service_principal" "aro_resource_provider" {
  display_name = var.resource_provider_service_principal_name
}

#
# managed identities
#
# NOTE: we index the following and use that index to get our ids to prevent 
#       a terraform error with count during apply.
#
# TODO: I believe we can handle this cleaner with for_each with a hash map 
#       but I am not sure.
locals {
  managed_identities = [
    "${var.cluster_name}-aro-service",              # 0
    "${var.cluster_name}-cloud-controller-manager", # 1
    "${var.cluster_name}-cloud-network-config",     # 2
    "${var.cluster_name}-cluster",                  # 3
    "${var.cluster_name}-disk-csi-driver",          # 4
    "${var.cluster_name}-file-csi-driver",          # 5
    "${var.cluster_name}-image-registry",           # 6
    "${var.cluster_name}-ingress",                  # 7
    "${var.cluster_name}-machine-api",              # 8
  ]
}

resource "azurerm_user_assigned_identity" "aro" {
  count = var.enable_managed_identities ? length(local.managed_identities) : 0

  name                = local.managed_identities[count.index]
  location            = var.location
  resource_group_name = local.aro_resource_group_name
}

locals {
  vnet_managed_identity_ids = compact([
    try(azurerm_user_assigned_identity.aro[2].principal_id, null),
    try(azurerm_user_assigned_identity.aro[8].principal_id, null),
  ])

  subnet_managed_identity_ids = compact([
    try(azurerm_user_assigned_identity.aro[0].principal_id, null),
    try(azurerm_user_assigned_identity.aro[1].principal_id, null),
    try(azurerm_user_assigned_identity.aro[2].principal_id, null),
    try(azurerm_user_assigned_identity.aro[5].principal_id, null),
    try(azurerm_user_assigned_identity.aro[7].principal_id, null),
    try(azurerm_user_assigned_identity.aro[8].principal_id, null),
  ])

  route_table_managed_identity_ids = compact([
    try(azurerm_user_assigned_identity.aro[0].principal_id, null),
    try(azurerm_user_assigned_identity.aro[5].principal_id, null),
    try(azurerm_user_assigned_identity.aro[8].principal_id, null),
  ])

  nat_gateway_managed_identity_ids = compact([
    try(azurerm_user_assigned_identity.aro[0].principal_id, null),
    try(azurerm_user_assigned_identity.aro[5].principal_id, null),
  ])

  network_security_group_managed_identity_ids = compact([
    try(azurerm_user_assigned_identity.aro[0].principal_id, null),
    try(azurerm_user_assigned_identity.aro[1].principal_id, null),
    try(azurerm_user_assigned_identity.aro[5].principal_id, null),
    try(azurerm_user_assigned_identity.aro[8].principal_id, null),
  ])

  federated_credential_managed_identity_ids = compact([
    try(azurerm_user_assigned_identity.aro[3].principal_id, null),
  ])
}
