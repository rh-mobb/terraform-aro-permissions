#
# output created service principals and credentials to a file
#
resource "local_sensitive_file" "cluster_service_principal" {
  count = var.cluster_service_principal.create ? 1 : 0

  content         = <<-EOT
ARO_CLUSTER_SP_CLIENT_ID='${azuread_application.cluster[0].client_id}'
ARO_CLUSTER_SP_CLIENT_SECRET='${azuread_application_password.cluster[0].value}'
EOT
  filename        = "./${var.cluster_name}_cluster-sp-credentials.txt"
  file_permission = "0600"
}

resource "local_sensitive_file" "installer_service_principal" {
  count = local.installer_user_set ? 0 : ((var.installer_service_principal.create) ? 1 : 0)

  content         = <<-EOT
ARO_INSTALLER_SP_CLIENT_ID='${azuread_application.installer[0].client_id}'
ARO_INSTALLER_SP_CLIENT_SECRET='${azuread_application_password.installer[0].value}'
ARO_TENANT_ID='${data.azuread_client_config.current.tenant_id}'
EOT
  filename        = "./${var.cluster_name}_installer-sp-credentials.txt"
  file_permission = "0600"
}
