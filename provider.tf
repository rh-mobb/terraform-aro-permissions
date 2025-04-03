terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.53"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.21.1"
    }
  }
}

#
# provider configuration
#
data "azuread_client_config" "current" {}

data "azurerm_client_config" "current" {}

provider "azurerm" {
  environment     = var.environment
  subscription_id = var.subscription_id # we cannot use a local here due to import cycle; a null value uses the client config
  tenant_id       = var.tenant_id       # we cannot use a local here due to import cycle; a null value uses the client config

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {
  environment = var.environment
}
