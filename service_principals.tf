#
# cluster service principal
#
locals {
  cluster_service_principal_name = (var.cluster_service_principal.name == "") || (var.cluster_service_principal.name == null) ? "${var.cluster_name}-cluster" : var.cluster_service_principal.name
}

# NOTE: pull the existing service principal if one was passed and we are not creating it
data "azuread_service_principal" "cluster" {
  count = var.cluster_service_principal.create ? 0 : 1

  display_name = local.cluster_service_principal_name
}

# NOTE: create the service principal if creation is requested
resource "azuread_application_registration" "cluster" {
  count = var.cluster_service_principal.create ? 1 : 0

  display_name = local.cluster_service_principal_name
}

resource "azuread_application_password" "cluster" {
  count = var.cluster_service_principal.create ? 1 : 0

  display_name   = local.cluster_service_principal_name
  application_id = azuread_application_registration.cluster[0].id
}

resource "azuread_service_principal" "cluster" {
  count = var.cluster_service_principal.create ? 1 : 0

  client_id = azuread_application_registration.cluster[0].client_id
  owners    = [data.azuread_client_config.current.object_id]
}

#
# installer service principal
#
locals {
  installer_user_set               = (var.installer_user_name != "") && (var.installer_user_name != null)
  installer_service_principal_name = (var.installer_service_principal.name == "") || (var.installer_service_principal.name == null) ? "${var.cluster_name}-installer" : var.installer_service_principal.name
}

# NOTE: pull the existing service principal if one was passed and we are not creating it and the user is not set
data "azuread_service_principal" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 0 : 1)

  display_name = local.cluster_service_principal_name
}

resource "azuread_application_registration" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 1 : 0)

  display_name = local.installer_service_principal_name
}

resource "azuread_application_password" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 1 : 0)

  display_name   = local.installer_service_principal_name
  application_id = azuread_application_registration.installer[0].id
}

resource "azuread_service_principal" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 1 : 0)

  client_id = azuread_application_registration.installer[0].client_id
  owners    = [data.azuread_client_config.current.object_id]
}

#
# aro resource provider service principal
#   NOTE: this is created by the 'az provider register' commands and will be pre-existing.
#
data "azuread_service_principal" "aro_resource_provider" {
  display_name = "Azure Red Hat OpenShift RP"
}

#
# output associated ids
#
output "cluster_service_principal_client_id" {
  value = var.cluster_service_principal.create ? azuread_application_registration.cluster[0].client_id : data.azuread_service_principal.cluster[0].id
}

output "cluster_service_principal_client_secret" {
  value     = var.cluster_service_principal.create && var.cluster_service_principal.output_secret ? azuread_application_password.cluster[0].value : null
  sensitive = true
}

output "installer_service_principal_client_id" {
  value = local.installer_user_set ? null : ((var.installer_service_principal.create) ? azuread_application_registration.installer[0].client_id : data.azuread_service_principal.installer[0].id)
}

output "installer_service_principal_client_secret" {
  value     = local.installer_user_set ? null : (var.installer_service_principal.create && var.installer_service_principal.output_secret ? azuread_application_password.installer[0].value : null)
  sensitive = true
}

output "resource_provider_service_principal_client_id" {
  value = data.azuread_service_principal.aro_resource_provider.client_id
}
