##############################################################################
# This template shows how to create an ESO clusterstore, a secrets store cluster scoped, with api key authentication
# Two different secret types
# - username & password
# - arbitrary (for Cloudant resource key)
# are created and configured in two different externalsecret resources in two different namespaces
# leveraging on the same ESO clusterstore
# The username/password secret is stored into a dockerconfigjson K8s secret type
# The arbitrary secret is stored into an opaque K8s secret type
##############################################################################

# creation of the ESO ClusterStore (cluster wide scope) with apikey authentication
module "eso_clusterstore" {
  source                            = "../../modules/eso-clusterstore"
  eso_authentication                = "api_key"
  clusterstore_secret_apikey        = data.ibm_sm_iam_credentials_secret.secret_puller_secret.api_key
  region                            = local.sm_region
  clusterstore_helm_rls_name        = "cluster-store"
  clusterstore_secret_name          = "generic-cluster-api-key" #checkov:skip=CKV_SECRET_6
  clusterstore_name                 = "cluster-store"
  clusterstore_secrets_manager_guid = local.sm_guid
  eso_namespace                     = var.eso_namespace
  service_endpoints                 = var.service_endpoints
  depends_on = [
    module.external_secrets_operator
  ]
}

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
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.9.0"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.secrets_manager_group.secret_group_id
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-usernamepassword-secret"              # checkov:skip=CKV_SECRET_6
  secret_description      = "example secret in existing secret manager instance" #tfsec:ignore:general-secrets-no-plaintext-exposure # checkov:skip=CKV_SECRET_6
  secret_payload_password = local.userpass_apikey
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
  depends_on                = [module.eso_clusterstore]
  source                    = "../../modules/eso-external-secret"
  es_kubernetes_secret_type = "dockerconfigjson"  #checkov:skip=CKV_SECRET_6
  sm_secret_type            = "username_password" #checkov:skip=CKV_SECRET_6
  sm_secret_id              = module.sm_userpass_secret.secret_id
  es_kubernetes_namespace   = kubernetes_namespace.apikey_namespaces[0].metadata[0].name
  eso_store_name            = "cluster-store"
  es_container_registry     = "example-registry-local.artifactory.com"
  es_kubernetes_secret_name = "dockerconfigjson-uc" #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "es-docker-uc"
}
