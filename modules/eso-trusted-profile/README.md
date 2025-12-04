# ESO Trusted Profile Module

This module allows to create and configure an Trusted Profile to authenticate with ESO operator.

For more information about Trusted Profiles refer to the IBM Cloud documentation available [here](https://cloud.ibm.com/docs/account?topic=account-create-trusted-profile&interface=ui)

## Usage

```hcl
# Replace "master" with a GIT release version to lock into a specific release
module "clusterstore_trusted_profile" {
  source                          = "git::https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator.git//modules/eso-trusted-profile?ref=master"
  trusted_profile_name            = local.cstore_trusted_profile_name
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = [module.tp_clusterstore_secrets_manager_group.secret_group_id]
  tp_cluster_crn                  = module.ocp_base.cluster_crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.51.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [ibm_iam_trusted_profile.trusted_profile](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_trusted_profile) | resource |
| [ibm_iam_trusted_profile_claim_rule.claim_rule](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_trusted_profile_claim_rule) | resource |
| [ibm_iam_trusted_profile_policy.policy](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_trusted_profile_policy) | resource |
| [ibm_iam_trusted_profile_policy.policy_multiple_secrets_groups](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_trusted_profile_policy) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_secret_groups_id"></a> [secret\_groups\_id](#input\_secret\_groups\_id) | The list of secret groups to limit access to for the trusted profile to create. | `list(string)` | `[]` | no |
| <a name="input_secrets_manager_guid"></a> [secrets\_manager\_guid](#input\_secrets\_manager\_guid) | Secrets manager instance GUID where secrets will be stored or fetched from and the trusted profile will allow access to. | `string` | n/a | yes |
| <a name="input_tp_cluster_crn"></a> [tp\_cluster\_crn](#input\_tp\_cluster\_crn) | Target cluster CRN for the trusted profile. Used when creating trusted profile | `string` | n/a | yes |
| <a name="input_tp_namespace"></a> [tp\_namespace](#input\_tp\_namespace) | Namespace to configure in the Trusted Profile on IAM. Its value must be the namespace where the operator is deployed and running. | `string` | n/a | yes |
| <a name="input_trusted_profile_claim_rule_type"></a> [trusted\_profile\_claim\_rule\_type](#input\_trusted\_profile\_claim\_rule\_type) | Trusted profile claim rule type, set the value to 'ROKS\_SA' for ROKS clusters, set to ROKS for IKS clusters | `string` | `"ROKS_SA"` | no |
| <a name="input_trusted_profile_name"></a> [trusted\_profile\_name](#input\_trusted\_profile\_name) | The name of the trusted profile to be used. This allows ESO to use CRI based authentication to access secrets manager. The trusted profile must be created in advance | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_trusted_profile_id"></a> [trusted\_profile\_id](#output\_trusted\_profile\_id) | ID of the trusted profile |
| <a name="output_trusted_profile_name"></a> [trusted\_profile\_name](#output\_trusted\_profile\_name) | Name of the trusted profile |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
