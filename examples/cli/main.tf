data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {}
}

module "example" {
  source = "../../"

  cluster_name = "example"
  vnet         = "example-aro-vnet-eastus"
  aro_resource_group = {
    name   = "example-vnet-rg"
    create = false
  }

  minimal_network_role = "dscott-test"

  subscription_id = data.azurerm_client_config.current.subscription_id
  tenant_id       = data.azurerm_client_config.current.tenant_id
}
