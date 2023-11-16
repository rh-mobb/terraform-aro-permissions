variable "cluster_name" {
  type        = string
  description = "Name of the cluster to setup permissions for."
}

# NOTE: if using Terraform or other automation tool, use 'api' as the installation type.
variable "installation_type" {
  type        = string
  default     = "cli"
  description = "The installation type that will be used to create the ARO cluster.  One of: [api, cli]"

  validation {
    condition     = contains(["api", "cli"], var.installation_type)
    error_message = "'installation_type' must be one of: ['api', 'cli']."
  }
}

#
# service principals and users
#
variable "cluster_service_principal" {
  type = object({
    name          = string
    create        = bool
    output_secret = bool
  })
  default = {
    name          = null
    create        = true
    output_secret = true
  }
  description = "Cluster Service Principal to use or optionally create.  If name is unset, the cluster_name is used to derive a name."
}

variable "installer_service_principal" {
  type = object({
    name          = string
    create        = bool
    output_secret = bool
  })
  default = {
    name          = null
    create        = true
    output_secret = true
  }
  description = "Installer Service Principal to use or optionally create.  If name is unset, the cluster_name is used to derive a name.  Overridden if an 'installer_user_name' is specified."
}

variable "installer_user_name" {
  type        = string
  default     = ""
  description = "User who will be executing the installation (e.g. via az aro create).  This overrides the 'installer_service_principal'."
}

#
# objects
#
variable "aro_resource_group" {
  type = object({
    name   = string
    create = bool
  })
  default = {
    name   = null
    create = true
  }
  description = "ARO resource group to use or optionally create."

  validation {
    condition     = ((var.aro_resource_group.name != null) && (var.aro_resource_group.name != "") && (var.aro_resource_group.create == false)) || var.aro_resource_group.create
    error_message = "'aro_resource_group.name' is a required value if 'aro_resource_group.create' is set to 'false'."
  }
}

variable "vnet" {
  type        = string
  description = "VNET where ARO will be deployed into."
}

variable "vnet_resource_group" {
  type        = string
  default     = null
  description = "Resource Group where the VNET resides.  If unspecified, defaults to 'aro_resource_group.name'."
}

# TODO: pull from data sources
variable "vnet_has_route_tables" {
  type        = bool
  default     = false
  description = "Specify if the VNET has route tables attached."
}

# TODO: pull from data sources
variable "vnet_has_nat_gateways" {
  type        = bool
  default     = false
  description = "Specify if the VNET has NAT gateways attached."
}

variable "network_security_group" {
  type        = string
  default     = null
  description = "Network security group used in a BYO-NSG scenario."
}

#
# roles
#
variable "minimal_network_role" {
  type        = string
  default     = null
  description = "Role to substitute for full 'Network Contributor' on network objects.  If specified, this is created."
}

variable "minimal_aro_role" {
  type        = string
  default     = null
  description = "Role to substitute for full 'Contributor' on the ARO resource group.  If specified, this is created."
}

#
# azure variables
#
variable "environment" {
  type        = string
  default     = "public"
  description = "Explicitly use a specific Azure environment.  One of: [public, usgovernment, dod]."

  validation {
    condition     = contains(["public", "usgovernment", "dod"], var.environment)
    error_message = "'environment' must be one of: ['public', 'usgovernment', 'dod']."
  }
}

variable "subscription_id" {
  type        = string
  default     = null
  description = "Explicitly use a specific Azure subscription id (defaults to the current system configuration)."
}

variable "tenant_id" {
  type        = string
  default     = null
  description = "Explicitly use a specific Azure tenant id (defaults to the current system configuration)."
}
