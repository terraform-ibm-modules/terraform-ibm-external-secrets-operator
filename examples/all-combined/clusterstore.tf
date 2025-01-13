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
  version              = "1.4.0"
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
  es_container_registry     = "wcp-my-team-docker-local.artifactory.swg-devops.com"
  es_kubernetes_secret_name = "dockerconfigjson-uc" #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "es-docker-uc"
}

### temporary disabled the test on the Cloudant resource key blocking the tests because of potential issue with Cloudant instance creation
### https://github.ibm.com/GoldenEye/issues/issues/7726

##################################################################
# creation of arbitrary secret to store Cloudant resource key
# A Cloudant instance is created in advance to create its resource key
##################################################################

##############################################################################
# Basic cloudant instance + database
##############################################################################

# module "cloudant" {
#   source            = "terraform-ibm-modules/cloudant/ibm"
#   version           = "1.1.7"
#   resource_group_id = module.resource_group.resource_group_id
#   instance_name     = "${var.prefix}-cloudant"
#   access_tags       = []
#   region            = var.region
#   tags              = var.resource_tags
#   plan              = "lite"
#   database_config = []
# }

# # load cloudant instance details when ready
# data "ibm_cloudant" "instance" {
#   # forcing on depend instead of id because it triggers a validation error
#   depends_on        = [module.cloudant]
#   # id                = module.cloudant.instance_id
#   name              = module.cloudant.instance_name
#   resource_group_id = module.resource_group.resource_group_id
# }

# # create resource key for cloudant instance
# resource "ibm_resource_key" "resource_key" {
#   name                 = "cd-resource-key"
#   role                 = "Manager"
#   resource_instance_id = data.ibm_cloudant.instance.id
#   timeouts {
#     create = "15m"
#     delete = "15m"
#   }
# }

# # Creates the arbitrary secret to store the cloudant resource key in secrets manager
# module "sm_arbitrary_cloudant_secret" {
#   source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
#   version              = "1.1.1"
#   region               = local.sm_region
#   secrets_manager_guid = local.sm_guid
#   secret_group_id      = module.secrets_manager_group.secret_group_id
#   secret_type          = "arbitrary"
#   #tfsec:ignore:general-secrets-no-plaintext-exposure
#   secret_name             = "${var.prefix}-cloudant-rk-secret"                   #checkov:skip=CKV_SECRET_6
#   secret_description      = "example secret in existing secret manager instance" #tfsec:ignore:general-secrets-no-plaintext-exposure
#   secret_payload_password = ibm_resource_key.resource_key.credentials["apikey"]
#   providers = {
#     ibm = ibm.ibm-sm
#   }
# }

# # ESO externalsecret with cluster scope creating opaque type secret
# module "external_secret_arbitrary_cloudant" {
#   depends_on                    = [module.eso_clusterstore]
#   source                        = "../../modules/eso-external-secret"
#   eso_store_scope               = "cluster"
#   es_kubernetes_secret_type     = "opaque"
#   sm_secret_type                = "arbitrary"
#   sm_secret_id                  = module.sm_arbitrary_cloudant_secret.secret_id
#   es_kubernetes_namespace       = kubernetes_namespace.apikey_namespaces[1].metadata[0].name
#   eso_store_name                = "cluster-store"
#   es_refresh_interval           = "5m"
#   es_kubernetes_secret_data_key = "apikey"
#   es_kubernetes_secret_name     = "cloudant-opaque-arb" #checkov:skip=CKV_SECRET_6
#   es_helm_rls_name              = "es-cloudant-arb"
# }
