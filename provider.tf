terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.45.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

#
# provider configuration
#
data "azuread_client_config" "current" {}

data "azurerm_client_config" "current" {}

locals {
  subscription_id = var.subscription_id == null || var.subscription_id == "" ? data.azurerm_client_config.current.subscription_id : var.subscription_id
  tenant_id       = var.tenant_id == null || var.tenant_id == "" ? data.azurerm_client_config.current.tenant_id : var.tenant_id
}

provider "azurerm" {
  environment     = var.environment
  subscription_id = local.subscription_id
  tenant_id       = local.tenant_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {
  environment = var.environment
}
