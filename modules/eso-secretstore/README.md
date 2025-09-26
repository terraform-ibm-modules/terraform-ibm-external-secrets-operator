# ESO (Namespaced) Secret Store Module

This module allows to configure an [SecretStore](https://external-secrets.io/latest/api/secretstore/) resource for an ESO secret store with namespace scope, in the desired namespace and with the desired configurations.

For more information about SecretStore resource and about ESO please refer to the ESO documentation available [here](https://external-secrets.io/v0.8.3/guides/introduction/)

This module supports SecretStore two authentication configurations to pull/push secrets with the configured Secrets Manager instance:
- apikey authentication
- trusted profile authentication

For more information about Trusted Profiles refer to the IBM Cloud documentation available [here](https://cloud.ibm.com/docs/account?topic=account-create-trusted-profile&interface=ui)

## Usage

```hcl
# Replace "master" with a GIT release version to lock into a specific release
module "eso_apikey_secretstore" {
  source                      = "git::https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator.git//modules/eso-secretstore?ref=master"
  eso_authentication          = "api_key"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace.apikey_namespaces.metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "${var.es_namespaces_apikey}-store"
  sstore_secret_apikey        = data.ibm_sm_iam_credentials_secret.secret_puller_secret.api_key # pragma: allowlist secret
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store"
  sstore_secret_name          = "generic-cluster-api-key"
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0, <4.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.16.1, <3.0.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [helm_release.external_secret_store_apikey](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.external_secret_store_tp](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret.eso_secretsstore_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eso_authentication"></a> [eso\_authentication](#input\_eso\_authentication) | Authentication method, Possible values are api\_key or/and trusted\_profile. | `string` | `"trusted_profile"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region where Secrets Manager is deployed. It will be used to build the regional URL to the service | `string` | n/a | yes |
| <a name="input_service_endpoints"></a> [service\_endpoints](#input\_service\_endpoints) | The service endpoint type to communicate with the provided secrets manager instance. Possible values are `public` or `private`. This also will set the iam endpoint for containerAuth when enabling Trusted Profile/CR based authentication. | `string` | `"public"` | no |
| <a name="input_sstore_helm_rls_name"></a> [sstore\_helm\_rls\_name](#input\_sstore\_helm\_rls\_name) | Name of helm release for the secrets store | `string` | `"external-secret-store"` | no |
| <a name="input_sstore_namespace"></a> [sstore\_namespace](#input\_sstore\_namespace) | Namespace to create the secret store. The namespace must exist as it is not created by this module | `string` | n/a | yes |
| <a name="input_sstore_secret_apikey"></a> [sstore\_secret\_apikey](#input\_sstore\_secret\_apikey) | APIkey to be stored into var.sstore\_secret\_name secret to authenticate with Secrets Manager instance | `string` | `null` | no |
| <a name="input_sstore_secret_name"></a> [sstore\_secret\_name](#input\_sstore\_secret\_name) | Secret name to be used/referenced in the ESO secretsstore to pull from Secrets Manager | `string` | `"ibm-secret"` | no |
| <a name="input_sstore_secrets_manager_guid"></a> [sstore\_secrets\_manager\_guid](#input\_sstore\_secrets\_manager\_guid) | Secrets manager instance GUID for secrets store where secrets will be stored or fetched from | `string` | n/a | yes |
| <a name="input_sstore_store_name"></a> [sstore\_store\_name](#input\_sstore\_store\_name) | Name of the SecretStore to create | `string` | n/a | yes |
| <a name="input_sstore_trusted_profile_name"></a> [sstore\_trusted\_profile\_name](#input\_sstore\_trusted\_profile\_name) | The name of the trusted profile to use for the secrets store. This allows ESO to use CRI based authentication to access secrets manager. The trusted profile must be created in advance | `string` | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_release_secret_store"></a> [helm\_release\_secret\_store](#output\_helm\_release\_secret\_store) | SecretStore helm release. Returning the helm release for trusted profile or apikey authentication according to the authentication type |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
