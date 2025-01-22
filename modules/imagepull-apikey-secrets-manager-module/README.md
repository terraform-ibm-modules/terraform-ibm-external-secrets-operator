# ImagePull API key Secrets Manager module

[![Certified](<https://img.shields.io/badge/Status-Certified%20(GA)-brightgreen?style=plastic>)](https://github.ibm.com/GoldenEye/documentation/blob/master/status.md) [![CI](https://img.shields.io/badge/CI-Toolchain%20Tekton%20Pipeline-3662FF?logo=ibm)](https://cloud.ibm.com/devops/toolchains/c3916535-165a-4275-9b1f-c58575839951?env_id=ibm:yp:us-south) [![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release) [![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit) [![latest release](https://shields-server.m03l6u0cqkx.eu-de.codeengine.appdomain.cloud/github/v/release/GoldenEye/imagepull-apikey-secrets-manager-module?logo=GitHub)](https://github.ibm.com/GoldenEye/imagepull-apikey-secrets-manager-module/releases/latest)

<!-- Below content is automatically populated via pre-commit hook -->
<!-- BEGIN OVERVIEW HOOK -->
## Overview
* [imagepull-apikey-secrets-manager-module](#imagepull-apikey-secrets-manager-module)
* [Examples](./examples)
    * [Example creating ImagePull serviceID and storing its API key in a Secrets-Manager instance](./examples/complete)
* [Contributing](#contributing)
<!-- END OVERVIEW HOOK -->

## Compliance and security
This module implements the following NIST controls on the network layer. For more information about how this module implements the controls in the following list, see [NIST controls](docs/controls.md).

|Profile|Category|ID|Description|
|---|---|---|---|
| NIST | AC-3 |	AC-3 | The information system enforces approved authorizations for logical access to information and system resources in accordance with applicable access control policies.|
|NIST|IA-5| IA-5(g)| Protect authenticator content from unauthorized disclosure and modification. |


<!-- Match this heading to the name of the root level module (the repo name) -->
## imagepull-apikey-secrets-manager-module

A module to generate and store a service ID API key in IBM Cloud Secrets Manager that can be used in an `imagePullSecret` for pulling images from an IBM Container Registry.
For more information about image pull secrets, see [Creating an image pull secret](https://cloud.ibm.com/docs/containers?topic=containers-registry#other_registry_accounts) in "Setting up an image registry" in Cloud docs.

   :exclamation: Important: To use and generate dynamic secrets, Secrets Manager requires a properly configured [IAM credentials engine](https://cloud.ibm.com/docs/secrets-manager?topic=secrets-manager-configure-iam-engine&interface=ui). Use the [Secrets Manager module](https://github.ibm.com/GoldenEye/secrets-manager-module) for the configuration.


### Usage

```hcl
##############################################################################
# Config providers
##############################################################################
provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key  # pragma: allowlist secret
  region           = var.region
}

##################################################################
## Dynamic Service ID API Key / SM secret for image-pull
##################################################################

# Replace "master" with a GIT release version to lock into a specific release

module "image_pull" {
  source                     = "git::https://github.ibm.com/GoldenEye/imagepull-apikey-secrets-manager-module.git?ref=master"
  resource_group_id          = module.resource_group.resource_group_id
  secrets_manager_guid       = module.secrets_manager_iam_configuration.secrets_manager_guid
  cr_namespace_name          = "cr-namespace"
  service_id_secret_group_id = module.secrets_manager_iam_configuration.acct_secret_group_id
  region                     = var.region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  service_id_secret_name = "image-pull-service-id"
  depends_on             = [module.secrets_manager_iam_configuration]
}
```
### Required IAM access policies
You need the following permissions to run this module.

<!--
Update these sample permissions, following this format. Replace the sample
Cloud service name and roles with the information in the console at
Manage > Access (IAM) > Access groups > Access policies.
 -->

- Account Management
  - **IAM Identity** service
      - `Operator` platform access
      - `Administrator` platform access
- IAM services
  - **Secrets Manager** service
    - `Writer` service access
  - **No service access**
    - **Resource Group** \<your resource group>
    - `Viewer` resource group access

For more information about the access you need to run all the GoldenEye modules, see [GoldenEye IAM permissions](https://github.ibm.com/GoldenEye/documentation/blob/master/goldeneye-iam-permissions.md).

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= v1.0.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.51.0, < 2.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.1, < 1.0.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dynamic_serviceid_apikey"></a> [dynamic\_serviceid\_apikey](#module\_dynamic\_serviceid\_apikey) | terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm | 1.1.1 |

### Resources

| Name | Type |
|------|------|
| [ibm_iam_service_id.image_secret_pull_service_id](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_service_id) | resource |
| [ibm_iam_service_policy.cr_policy](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_service_policy) | resource |
| [time_sleep.wait_30_seconds_for_creation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait_30_seconds_for_destruction](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cr_namespace_name"></a> [cr\_namespace\_name](#input\_cr\_namespace\_name) | Container registry namespace name to be configured in IAM policy. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region where resources will be sourced / created | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | The resource group ID in which the container registry namespace exists (used in IAM policy configuration). | `string` | n/a | yes |
| <a name="input_secrets_manager_guid"></a> [secrets\_manager\_guid](#input\_secrets\_manager\_guid) | Secrets manager instance GUID where secrets will be stored or fetched from | `string` | n/a | yes |
| <a name="input_service_id_description"></a> [service\_id\_description](#input\_service\_id\_description) | Description to be used for ServiceID. | `string` | `"ServiceId used to access container registry"` | no |
| <a name="input_service_id_name"></a> [service\_id\_name](#input\_service\_id\_name) | Name to be used for ServiceID. | `string` | `"sid:0.0.1:image-secret-pull:automated:simple-service:container-registry:"` | no |
| <a name="input_service_id_secret_description"></a> [service\_id\_secret\_description](#input\_service\_id\_secret\_description) | Description to be used for ServiceID API Key. | `string` | `"API Key associated with image pull serviceid"` | no |
| <a name="input_service_id_secret_group_id"></a> [service\_id\_secret\_group\_id](#input\_service\_id\_secret\_group\_id) | Secret Group ID of SM IAM secret where Service ID apikey will be stored. Leave default (null) to add in default secret-group. | `string` | `null` | no |
| <a name="input_service_id_secret_name"></a> [service\_id\_secret\_name](#input\_service\_id\_secret\_name) | Name of SM IAM secret (dynamic ServiceID API Key) to be created. | `string` | `"image-pull-iam-secret"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_secret_manager_guid"></a> [secret\_manager\_guid](#output\_secret\_manager\_guid) | GUI of Secrets-Manager containing secret |
| <a name="output_serviceid_apikey_secret_id"></a> [serviceid\_apikey\_secret\_id](#output\_serviceid\_apikey\_secret\_id) | ID of the Secret Manager Secret containing ServiceID API Key |
| <a name="output_serviceid_name"></a> [serviceid\_name](#output\_serviceid\_name) | Name of the ServiceID created to access Container Registry |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- Leave this section as is so that your module has a link to local development environment set up steps for contributors to follow -->
## Contributing

You can report issues and request features for this module in the GoldenEye [issues](https://github.ibm.com/GoldenEye/issues) repo.See [Report a Bug or Create Enhancement Request](https://github.ibm.com/GoldenEye/documentation/blob/master/issues.md).

To set up your local development environment, see [Local development setup](https://github.ibm.com/GoldenEye/documentation/blob/master/local-dev-setup.md) in the project documentation.
