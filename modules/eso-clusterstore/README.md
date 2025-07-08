# ESO Cluster Store Module

This module allows to configure an [ClusterSecretStore](https://external-secrets.io/latest/api/clustersecretstore/) resource for an ESO secret store with cluster scope, in the desired namespace (the same of the ESO deploymet is a requirement of ESO and it is up to the consumer) and with the desired configurations.

For more information about ClusterSecretStore resource and about ESO please refer to the ESO documentation available [here](https://external-secrets.io/v0.8.3/guides/introduction/)

This module supports ClusterSecretStore two authentication configurations to pull/push secrets with the configured Secrets Manager instance:
- apikey authentication
- trusted profile authentication

For more information about Trusted Profiles refer to the IBM Cloud documentation available [here](https://cloud.ibm.com/docs/account?topic=account-create-trusted-profile&interface=ui)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.16.1, <3.0.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [helm_release.cluster_secret_store_apikey](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.cluster_secret_store_tp](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret.eso_clusterstore_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_clusterstore_helm_rls_name"></a> [clusterstore\_helm\_rls\_name](#input\_clusterstore\_helm\_rls\_name) | Name of helm release for cluster secrets store | `string` | `"cluster-secret-store"` | no |
| <a name="input_clusterstore_name"></a> [clusterstore\_name](#input\_clusterstore\_name) | Name of the ESO cluster secrets store to be used/created for cluster scope. | `string` | `"clustersecret-store"` | no |
| <a name="input_clusterstore_secret_apikey"></a> [clusterstore\_secret\_apikey](#input\_clusterstore\_secret\_apikey) | APIkey to be configured in the clusterstore\_secret\_name secret in the ESO cluster secrets store. One between clusterstore\_secret\_apikey and clusterstore\_trusted\_profile\_name must be filled | `string` | `null` | no |
| <a name="input_clusterstore_secret_name"></a> [clusterstore\_secret\_name](#input\_clusterstore\_secret\_name) | Secret name to be used/referenced in the ESO cluster secrets store to pull from Secrets Manager | `string` | `"ibm-secret"` | no |
| <a name="input_clusterstore_secrets_manager_guid"></a> [clusterstore\_secrets\_manager\_guid](#input\_clusterstore\_secrets\_manager\_guid) | Secrets manager instance GUID for cluster secrets store where secrets will be stored or fetched from | `string` | n/a | yes |
| <a name="input_clusterstore_trusted_profile_name"></a> [clusterstore\_trusted\_profile\_name](#input\_clusterstore\_trusted\_profile\_name) | The name of the trusted profile to use for cluster secrets store scope. This allows ESO to use CRI based authentication to access secrets manager. The trusted profile must be created in advance | `string` | `null` | no |
| <a name="input_eso_authentication"></a> [eso\_authentication](#input\_eso\_authentication) | Authentication method, Possible values are api\_key or/and trusted\_profile. | `string` | `"trusted_profile"` | no |
| <a name="input_eso_namespace"></a> [eso\_namespace](#input\_eso\_namespace) | Namespace where the ESO is deployed. It will be used to deploy the cluster secrets store | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region where Secrets Manager is deployed. It will be used to build the regional URL to the service | `string` | n/a | yes |
| <a name="input_service_endpoints"></a> [service\_endpoints](#input\_service\_endpoints) | The service endpoint type to communicate with the provided secrets manager instance. Possible values are `public` or `private`. This also will set the iam endpoint for containerAuth when enabling Trusted Profile/CR based authentication. | `string` | `"public"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_release_cluster_store"></a> [helm\_release\_cluster\_store](#output\_helm\_release\_cluster\_store) | ClusterSecretStore helm release. Returning the helm release for trusted profile or apikey authentication according to the authentication type |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
