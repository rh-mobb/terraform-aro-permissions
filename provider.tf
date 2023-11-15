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

data "azuread_client_config" "current" {}

provider "azurerm" {
  environment     = var.environment
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {
  environment = var.environment
}
