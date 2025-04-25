# ESO External Secrets Module

This module allows to configure an [ExternalSecrets](https://external-secrets.io/latest/api/externalsecret/) resource in the desired namespace and with the desired configurations.

It if possible to create ExternalSecret resource referencing either:
- a `ClusterSecretStore` for store with cluster scope
- a `SecretStore` for 'namespace' for regular namespaced scope
by correctly setting the related input variable `eso_store_scope`

For more information about ExternalSecrets on ESO please refer to the ESO documentation available [here](https://external-secrets.io/v0.8.3/guides/introduction/)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.8.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [helm_release.kubernetes_secret](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kubernetes_secret_certificate](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kubernetes_secret_chain_list](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kubernetes_secret_kv_all](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kubernetes_secret_kv_key](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kubernetes_secret_user_pw](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_es_container_registry"></a> [es\_container\_registry](#input\_es\_container\_registry) | The registry URL to be used in dockerconfigjson | `string` | `"us.icr.io"` | no |
| <a name="input_es_container_registry_email"></a> [es\_container\_registry\_email](#input\_es\_container\_registry\_email) | Optional - Email to be used in dockerconfigjson | `string` | `null` | no |
| <a name="input_es_container_registry_secrets_chain"></a> [es\_container\_registry\_secrets\_chain](#input\_es\_container\_registry\_secrets\_chain) | Structure to generate a chain of secrets into a single dockerjsonconfig secret for multiple registries authentication. | <pre>list(object({<br/>    es_container_registry       = string<br/>    sm_secret_id                = string # id of the secret storing the apikey that will be used for the secrets chain<br/>    es_container_registry_email = optional(string, null)<br/>    trusted_profile             = optional(string, null)<br/>  }))</pre> | `[]` | no |
| <a name="input_es_helm_rls_name"></a> [es\_helm\_rls\_name](#input\_es\_helm\_rls\_name) | Name to use for the helm release for externalsecrets resource. Must be unique in the namespace | `string` | n/a | yes |
| <a name="input_es_helm_rls_namespace"></a> [es\_helm\_rls\_namespace](#input\_es\_helm\_rls\_namespace) | Namespace to deploy the helm release for the externalsecret. Default if null is the externalsecret namespace | `string` | `null` | no |
| <a name="input_es_kubernetes_namespace"></a> [es\_kubernetes\_namespace](#input\_es\_kubernetes\_namespace) | Namespace to use to generate the externalsecret | `string` | n/a | yes |
| <a name="input_es_kubernetes_secret_data_key"></a> [es\_kubernetes\_secret\_data\_key](#input\_es\_kubernetes\_secret\_data\_key) | Data key to be used in Kubernetes Opaque secret. Only needed when 'es\_kubernetes\_secret\_type' is configured as `opaque` and sm\_secret\_type is set to either 'arbitrary' or 'iam\_credentials' | `string` | `null` | no |
| <a name="input_es_kubernetes_secret_name"></a> [es\_kubernetes\_secret\_name](#input\_es\_kubernetes\_secret\_name) | Name of the secret to use for the kubernetes secret object | `string` | n/a | yes |
| <a name="input_es_kubernetes_secret_type"></a> [es\_kubernetes\_secret\_type](#input\_es\_kubernetes\_secret\_type) | Secret type/format to be installed in the Kubernetes/Openshift cluster by ESO. Valid inputs are `opaque` `dockerconfigjson` and `tls` | `string` | n/a | yes |
| <a name="input_es_refresh_interval"></a> [es\_refresh\_interval](#input\_es\_refresh\_interval) | Specify interval for es secret synchronization. See recommendations for specifying/customizing refresh interval in this IBM Cloud article > https://cloud.ibm.com/docs/secrets-manager?topic=secrets-manager-tutorial-kubernetes-secrets#kubernetes-secrets-best-practices | `string` | `"1h"` | no |
| <a name="input_eso_store_name"></a> [eso\_store\_name](#input\_eso\_store\_name) | ESO store name to use when creating the externalsecret. Cannot be null and it is mandatory | `string` | n/a | yes |
| <a name="input_eso_store_scope"></a> [eso\_store\_scope](#input\_eso\_store\_scope) | Set to 'cluster' to configure ESO store as with cluster scope (ClusterSecretStore) or 'namespace' for regular namespaced scope (SecretStore). This value is used to configure the externalsecret reference | `string` | `"cluster"` | no |
| <a name="input_reloader_watching"></a> [reloader\_watching](#input\_reloader\_watching) | Flag to enable/disable the reloader watching. If enabled the reloader will watch for changes in the secret and reload the associated annotated pods if needed | `bool` | `false` | no |
| <a name="input_sm_certificate_bundle"></a> [sm\_certificate\_bundle](#input\_sm\_certificate\_bundle) | Flag to enable if the public/intermediate certificate is bundled. If enabled public key is managed as bundled with intermediate and private key, otherwise the template considers the public key not bundled with intermediate certificate and private key | `bool` | `true` | no |
| <a name="input_sm_certificate_has_intermediate"></a> [sm\_certificate\_has\_intermediate](#input\_sm\_certificate\_has\_intermediate) | The secret manager certificate is provided with intermediate certificate. By enabling this flag the certificate body on kube will contain certificate and intermediate content, otherwise only certificate will be added. Valid only for public and imported certificate | `bool` | `true` | no |
| <a name="input_sm_kv_keyid"></a> [sm\_kv\_keyid](#input\_sm\_kv\_keyid) | Secrets-Manager key value (kv) keyid | `string` | `null` | no |
| <a name="input_sm_kv_keypath"></a> [sm\_kv\_keypath](#input\_sm\_kv\_keypath) | Secrets-Manager key value (kv) keypath | `string` | `null` | no |
| <a name="input_sm_secret_id"></a> [sm\_secret\_id](#input\_sm\_secret\_id) | Secrets-Manager secret ID where source data will be synchronized with Kubernetes secret. It can be null only in the case of a dockerjsonconfig secrets chain | `string` | n/a | yes |
| <a name="input_sm_secret_type"></a> [sm\_secret\_type](#input\_sm\_secret\_type) | Secrets-manager secret type to be used as source data by ESO. Valid input types are 'iam\_credentials', 'username\_password', 'trusted\_profile', 'arbitrary', 'imported\_cert', 'public\_cert', 'private\_cert', 'kv' | `string` | n/a | yes |

### Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
