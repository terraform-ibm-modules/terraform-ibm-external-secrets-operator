## Example of leveraging the deployment of External Secrets Operator using this DA, the secrets configuration on IBM Cloud Secrets Manager and their binding on Cluster Secret Store on a cluster

The code below is an example of generating a username/password secret on Secrets Manager to deploy a dockerjson cluster secret for each Cluster Secrets Store:

```
##################################################################
# creation of generic username/password secret
# (for example to store artifactory username and API key)
##################################################################

locals {
  # secret value for sm_userpass_secret
  userpass_apikey = sensitive("password-payload-example")
}

# Create username_password secret and store in secret manager
module "sm_userpass_secret" {
  for_each = local.cluster_secrets_stores_account_secrets_groups
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.7.0"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = each.value.secrets_group.secret_group_id
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${each.key}-usernamepassword-secret"              # checkov:skip=CKV_SECRET_6
  secret_description      = "example secret for ${each.value.name}" #tfsec:ignore:general-secrets-no-plaintext-exposure # checkov:skip=CKV_SECRET_6
  secret_payload_password = local.userpass_apikey # pragma: allowlist secret
  secret_type             = "username_password" #checkov:skip=CKV_SECRET_6
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_username               = "artifactory-user" # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_auto_rotation          = false
  secret_auto_rotation_interval = 0
  secret_auto_rotation_unit     = null
  providers = {
    ibm = ibm.ibm-sm
  }
}

##################################################################
# ESO externalsecrets with cluster scope and apikey authentication
##################################################################

# ESO externalsecret with cluster scope creating a dockerconfigjson type secret
module "external_secret_usr_pass" {
  for_each = local.cluster_secrets_store_account_serviceid_apikey_secrets
  depends_on                = [module.eso_clustersecretsstore]
  source                    = "../../modules/eso-external-secret"
  es_kubernetes_secret_type = "dockerconfigjson"  #checkov:skip=CKV_SECRET_6
  sm_secret_type            = "username_password" #checkov:skip=CKV_SECRET_6
  sm_secret_id              = each.value.secrets_manager_secret.secret_id
  es_kubernetes_namespace   = var.eso_secretsstores_configuration.cluster_secrets_stores[each.key].namespace
  eso_store_name            = each.key
  es_container_registry     = "example-registry-local.artifactory.com"
  es_kubernetes_secret_name = "dockerconfigjson-uc" #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "es-docker-uc"
}

output "sm_userpass_secret" {
  value = module.sm_userpass_secret
}
```
