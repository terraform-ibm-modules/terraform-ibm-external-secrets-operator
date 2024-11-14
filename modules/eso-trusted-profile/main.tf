### Trusted Profiles resources

# creates a trusted profile to use for container authentication in external secrets operator
resource "ibm_iam_trusted_profile" "trusted_profile" {
  name        = var.trusted_profile_name
  description = "a trusted profile to access the secrets manager instance: ${var.secrets_manager_guid}."
}

# The following Rule allows incoming requests from
# the external-secrets SA in external-secrets namespce in the
# target cluster with the retrieved cluster's CRN.
resource "ibm_iam_trusted_profile_claim_rule" "claim_rule" {
  profile_id = ibm_iam_trusted_profile.trusted_profile.id
  type       = "Profile-CR"
  name       = "${var.trusted_profile_name}-rule"
  cr_type    = var.trusted_profile_claim_rule_type

  dynamic "conditions" {
    for_each = [
      {
        claim    = "name"
        operator = "EQUALS"
        value    = "\"external-secrets\""
      },
      {
        claim    = "namespace",
        operator = "EQUALS",
        value    = "\"${var.tp_namespace}\"",
      },
      {
        claim    = "crn",
        operator = "EQUALS",
        value    = "\"${var.tp_cluster_crn}\""
      }
    ]

    content {
      claim    = conditions.value["claim"]
      operator = conditions.value["operator"]
      value    = conditions.value["value"]
    }
  }
}

# This Trusted Profile policy grants access to the provided secrets
# manager instance, if one of more secret group ids are provided, it will then
# restrict access to these secret groups with SecretsReader role.

# migration definition to avoid destruction of resources with support of multiple secrets group
moved {
  from = module.your_trusted_profile_module_name.ibm_iam_trusted_profile_policy.policy
  to   = module.your_trusted_profile_module_name.ibm_iam_trusted_profile_policy.policy[0]
}

# This Trusted Profile policy grants access to the provided secrets
# manager instance, if no secrets group id or one secrets group id is provided to restrict the access to the Secrets Manager instance
resource "ibm_iam_trusted_profile_policy" "policy" {
  count       = length(var.secret_groups_id) <= 1 ? 1 : 0
  profile_id  = ibm_iam_trusted_profile.trusted_profile.id
  description = length(var.secret_groups_id) == 0 ? "IAM Trusted Profile Policy to access the secrets in the target secret groups and secrets manager instance and not restricted to any secrets group" : "IAM Trusted Profile Policy to access the secrets in the target secret group and secrets manager instance"
  roles       = ["SecretsReader"]
  resources {
    service              = "secrets-manager"
    resource_type        = length(var.secret_groups_id) == 1 ? "secret-group" : null
    resource             = length(var.secret_groups_id) == 1 ? var.secret_groups_id[0] : null
    resource_instance_id = var.secrets_manager_guid
  }
}

# This Trusted Profile policy grants acccess to the provided secrets
# manager instance, if two or more secrets groups id are provided to restrict the access to the Secrets Manager instance
resource "ibm_iam_trusted_profile_policy" "policy_multiple_secrets_groups" {
  count       = length(var.secret_groups_id) > 1 ? length(var.secret_groups_id) : 0
  profile_id  = ibm_iam_trusted_profile.trusted_profile.id
  description = "IAM Trusted Profile Policy to access the secrets in the target secrets group ${var.secret_groups_id[count.index]} and secrets manager instance"
  roles       = ["SecretsReader"]
  resources {
    service              = "secrets-manager"
    resource_type        = "secret-group"
    resource             = var.secret_groups_id[count.index]
    resource_instance_id = var.secrets_manager_guid
  }
}
