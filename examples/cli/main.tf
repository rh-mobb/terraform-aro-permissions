data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {}
}

module "example" {
  source = "../../"

  cluster_name = "dscott-test"
  vnet         = "dscott-test-aro-vnet-eastus"
  aro_resource_group = {
    name   = "dscott-rg"
    create = false
  }

  minimal_network_role = "dscott-test"

  subscription_id = data.azurerm_client_config.current.subscription_id
  tenant_id       = data.azurerm_client_config.current.tenant_id
}

#
# outputs
# 
output "cluster_service_principal_client_id" {
  value = module.example.cluster_service_principal_client_id
}

output "cluster_service_principal_client_secret" {
  value     = module.example.cluster_service_principal_client_secret
  sensitive = true
}

output "installer_service_principal_client_id" {
  value = module.example.installer_service_principal_client_id
}

output "installer_service_principal_installer_secret" {
  value     = module.example.installer_service_principal_client_secret
  sensitive = true
}

output "resource_provider_service_principal_client_id" {
  value = module.example.resource_provider_service_principal_client_id
}

output "vnet" {
  value = module.example.vnet
}
