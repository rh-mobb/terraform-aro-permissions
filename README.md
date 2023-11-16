# Summary

This project aims to provide a Terraform module to make it easy to setup Azure permissions needed to install 
and manage ARO.  The problem we see in the field, is that there are overlapping identities that need specific 
permission sets and this often times results in incorrect permissions and makes for a confusing experience.

> **WARN:** It should be noted that certain product changes will force this to change.  This is a community-supported 
product and you should consult your appropriate product documentation prior to using this in your environment 
to ensure it is appropriate for your needs.


## Identities

This section identifies the individual identities that need ARO permissions.  These identities will be used 
in verbiage when describing what permissions are needed.

> **NOTE:** the **Install Flags** column helps to associate these service principals to actual ARO installation flags
> using the CLI.

| Identity | Type | Install Flags | Description |
| ---- | ---- | ---- | ---- |
| Cluster Service Principal | Service Principal | `--client-id` and `--client-secret` | Runs all operations in the cluster and that interacts with the Azure API as part of operations within the cluster. Cluster Autoscaler and the Service Controller for Azure are two key components which leverage these credentials. |
| Installer | User or Service Principal | N/A | Whomever the installation process is run as.  This may be a user account or a service principal.  This is who is logged in using the `az login` command. |
| Resource Provider Service Principal | Service Principal | N/A | Azure Resource Provider that represents ARO.  This is automatically created in the account when first running the setup step `az provider register -n Microsoft.RedHatOpenShift --wait`.  This service principal can be found by running `az ad sp list --filter "displayname eq 'Azure Red Hat OpenShift RP'"`. |


## Objects

This section defines the objects which need individual permissions.

> **NOTE:** the **Install Flags** column helps to associate these objects to actual ARO installation flags
> using the CLI.

| Object Type | Install Flags | Description |
| ---- | ---- | ---- |
| Subscription | `--subscription` | The highest level a permission will be applied.  Inherits down to all objects within that subscription.  This is not a mandatory flag and the subscription may be set based on how a user has logged in with `az login`. |
| ARO Resource Group | `--resource-group` | Resource group in the above subscription where the actual ARO object is created. |
| Cluster Resource Group | `--cluster-resource-group` | Resource group in the above subscription where the underlying ARO object (e.g. VMs, load balancers) are created.  This is created automatically as part of provisioning. |
| Network Resource Group | `--vnet-resource-group` | Resource group in the above subscription where network resources (e.g. VNET, NSG) exist.  Some organizations will use the Cluster Resource Group for this purpose as well and do not need a dedicated Network Resource Group. |
| VNET | `--vnet`| VNET where the ARO cluster will be provisioned. |
| Network Security Group | N/A | Only required for BYO-NSG scenarios.  Network security group, applied to the subnets.  This is is pre-applied by the user to the subnets prior to installation. |


## Permissions

This section identifies what permissions are needed by each individual identity.

> NOTE: row numbers are used to indicate in the code where permissions are aligned.

| Permission Number | Identity | Object | Permission | Comment |
| ---- | ---- | ---- | ---- | ---- |
| 1 | [Cluster Service Principal](#identities) | [ARO Resource Group](#objects) | [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) | |
| 2 | [Cluster Service Principal](#identities) | Network Security Group | [Network Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#network-contributor) or [Minimal Network Permissions](#minimal-network-permissions) | Only needed if BYO-NSG is pre-attached to the subnet. |
| 3 | [Cluster Service Principal](#identities) | [VNET](#objects) | [Network Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#network-contributor) or [Minimal Network Permissions](#minimal-network-permissions) | |
| 4 | [Installer](#identities) | [ARO Resource Group](#objects) | [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) or [Minimal ARO Permissions](#minimal-aro-permissions) | |
| 5 | [Installer](#identities) | [Network Resource Group](#objects)| [Reader](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader) | Only required if `az aro create` is used to install. |
| 6 | [Installer](#identities) | [Subscription](#objects) | [User Access Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator) | Only required if `az aro create` is used to install. |
| 7 | [Installer](#identities) | Azure AD | [Directory Reader](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference#directory-readers) | Only required if `az aro create` is used to install. |
| 8 | [Installer](#identities) | [VNET](#objects) | [Network Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#network-contributor) or [Minimal Network Permissions](#minimal-network-permissions) | Only required if `az aro create` is used to install. |
| 9 | [Resource Provider Service Principal](#identities) | [VNET](#objects) | [Network Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#network-contributor) or [Minimal Network Permissions](#minimal-network-permissions) | |
| 10 | [Resource Provider Service Principal](#identities) | [Network Security Group](#objects) | [Network Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#network-contributor) or [Minimal Network Permissions](#minimal-network-permissions) | |
| 11 | [Resource Provider Service Principal](#identities) | [Cluster Resource Group](#objects) | [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) | This permission does not need to pre-exist.  It is applied when the Resource Provider Service Principal creates the resource group as part of installation.  This is for documentation purposes only. |


### Minimal Network Permissions

In many cases, such as separation of duties and where network teams must provide infrastructure to consume, a 
reduced permission set lower than [Network Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#network-contributor) is required.  This is possible, however it should be noted that [product documentation](https://learn.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#verify-your-permissions) indicates higher permissions and the product will
be developed against that assumption unless otherwise noted.

The following permission, in place of Network Contributor, have been successful (including links to the code which 
validates the permissions).  The VNET this applies to equates to the value of the `--vnet` flag in the `az aro create` command:

Needed always:

* [Microsoft.Network/virtualNetworks/join/action](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L221-L226)
* [Microsoft.Network/virtualNetworks/read](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L221-L226)
* [Microsoft.Network/virtualNetworks/write](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L221-L226)
* [Microsoft.Network/virtualNetworks/subnets/join/action](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L221-L226)
* [Microsoft.Network/virtualNetworks/subnets/read](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L221-L226)
* [Microsoft.Network/virtualNetworks/subnets/write](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L221-L226)
* [Microsoft.Network/networkSecurityGroups/join/action](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L846)

Needed when provided VNET has route table(s) attached:

* [Microsoft.Network/routeTables/join/action](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L301-L303)
* [Microsoft.Network/routeTables/read](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L301-L303)
* [Microsoft.Network/routeTables/write](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L301-L303)


Needed when provided VNET has NAT gateway(s) attached:

* [Microsoft.Network/natGateways/join/action](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L367-L369)
* [Microsoft.Network/natGateways/read](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L367-L369)
* [Microsoft.Network/natGateways/write](https://github.com/Azure/ARO-RP/blob/v20231110.00/pkg/validate/dynamic/dynamic.go#L367-L369)


### Minimal ARO Permissions

In addition to minimizing network permissions, the installer role may need minimal permissions as well.  These permissions are as follows:

* Microsoft.RedHatOpenShift/openShiftClusters/read
* Microsoft.RedHatOpenShift/openShiftClusters/write
* Microsoft.RedHatOpenShift/openShiftClusters/listCredentials/action
* Microsoft.RedHatOpenShift/openShiftClusters/listAdminCredentials/action


## Prereqs

Prior to running this module, the following must be satisfied:

1. Must be logged in as an administrator user using the `az login` command.  Because assigning permissions is an administrative task, 
it is assumed whomever is running this module is an administrator.

2. Must have the `az` CLI installed and configured locally.  There are some external commands ran in this module which makes this 
necessary.  It is not ideal but it works for now.

3. Must have the `jq` CLI installed locally.  There are some external commands ran in this module which makes this 
necessary.  It is not ideal but it works for now.

4. Must have a VNET architecture pre-deployed and used as an input.


## Usage

This section describes how to consume this module.