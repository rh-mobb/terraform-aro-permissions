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
resource "azuread_application" "cluster" {
  count = var.cluster_service_principal.create ? 1 : 0

  display_name = local.cluster_service_principal_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "cluster" {
  count = var.cluster_service_principal.create ? 1 : 0

  display_name          = local.cluster_service_principal_name
  application_object_id = azuread_application.cluster[0].object_id
}

resource "azuread_service_principal" "cluster" {
  count = var.cluster_service_principal.create ? 1 : 0

  application_id = azuread_application.cluster[0].application_id
  owners         = [data.azuread_client_config.current.object_id]
}

locals {
  cluster_service_principal_object_id = var.cluster_service_principal.create ? azuread_service_principal.cluster[0].object_id : data.azuread_service_principal.cluster[0].object_id
}

#
# installer service principal
#
locals {
  installer_user_set               = (var.installer_user != "") && (var.installer_user != null)
  installer_service_principal_name = (var.installer_service_principal.name == "") || (var.installer_service_principal.name == null) ? "${var.cluster_name}-installer" : var.installer_service_principal.name
}

# NOTE: pull the existing service principal if one was passed and we are not creating it and the user is not set
data "azuread_service_principal" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 0 : 1)

  display_name = local.cluster_service_principal_name
}

resource "azuread_application" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 1 : 0)

  display_name = local.installer_service_principal_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 1 : 0)

  display_name          = local.installer_service_principal_name
  application_object_id = azuread_application.installer[0].object_id
}

resource "azuread_service_principal" "installer" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 1 : 0)

  application_id = azuread_application.installer[0].application_id
  owners         = [data.azuread_client_config.current.object_id]
}

data "azuread_user" "installer" {
  count = local.installer_user_set ? 1 : 0

  user_principal_name = var.installer_user
}

locals {
  installer_service_principal_object_id = local.installer_user_set ? null : (var.installer_service_principal.create ? azuread_service_principal.installer[0].object_id : data.azuread_service_principal.installer[0].object_id)
  installer_user_object_id              = local.installer_user_set ? data.azuread_user.installer[0].object_id : null
  installer_object_id                   = local.installer_user_set ? local.installer_user_object_id : local.installer_service_principal_object_id
}

#
# aro resource provider service principal
#   NOTE: this is created by the 'az provider register' commands and will be pre-existing once that command has been run.
#
data "azuread_service_principal" "aro_resource_provider" {
  display_name = "Azure Red Hat OpenShift RP"
}
