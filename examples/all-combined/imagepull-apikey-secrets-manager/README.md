# ImagePull API key Secrets Manager

This module generate and store a service ID API key in IBM Cloud Secrets Manager that can be used in an imagePullSecret for pulling images from an IBM Container Registry. For more information about image pull secrets, see Creating an image pull secret in "Setting up an image registry" in Cloud docs.

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
| <a name="module_dynamic_serviceid_apikey"></a> [dynamic\_serviceid\_apikey](#module\_dynamic\_serviceid\_apikey) | terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm | 1.2.0 |

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
