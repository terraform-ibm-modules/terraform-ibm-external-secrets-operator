##############################################################################
# This template shows how to create ESO secretstores, a secrets store namespace scoped, with api key authentication
# Two different secretstores are created in two different namespaces, allowing to achive namespace isolation
# Two different secret types
# - arbitrary (to store image pull API key)
# - Image pull API key secret using imagepull-apikey-secrets-manager-module
# are created and configured in two different externalsecret resources configured with the two different secretstores
# Both the secrets are store into a dockerconfigjson K8s secret type
# The Image pull API key secret is stored into an opaque K8s secret type
##############################################################################

# creation of namespace scoped secretstore with apikey authentication
module "eso_apikey_namespace_secretstore_1" {
  depends_on                  = [module.external_secrets_operator]
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = "api_key"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace.apikey_namespaces[2].metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "${var.es_namespaces_apikey[2]}-store"
  sstore_secret_apikey        = data.ibm_sm_iam_credentials_secret.secret_puller_secret.api_key
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store"
  sstore_secret_name          = "generic-cluster-api-key" #checkov:skip=CKV_SECRET_6
}

module "eso_apikey_namespace_secretstore_2" {
  depends_on                  = [module.external_secrets_operator]
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = "api_key"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace.apikey_namespaces[3].metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "${var.es_namespaces_apikey[3]}-store"
  sstore_secret_apikey        = data.ibm_sm_iam_credentials_secret.secret_puller_secret.api_key
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store"
  sstore_secret_name          = "generic-cluster-api-key" #checkov:skip=CKV_SECRET_6
}

##################################################################
# Arbitrary secret (for example image pull secret)
##################################################################

locals {
  # image pull API key value for sm_arbitrary_imagepull_secret
  imagepull_apikey = sensitive("imagepull-payload-example")
}

# create the arbitrary secret and store in secret manager
module "sm_arbitrary_imagepull_secret" {
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.4.0"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.secrets_manager_group.secret_group_id
  secret_type          = "arbitrary"
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-imagepull-apikey-secret"          #checkov:skip=CKV_SECRET_6
  secret_description      = "example secret for provided image pull API key" #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_payload_password = local.imagepull_apikey
  providers = {
    ibm = ibm.ibm-sm
  }
}

# creation of externalsecret for the arbitrary secret in namespaced secretstore with API key authentication
# secrets stored in K8s dockerconfigjson secret type
module "external_secret_arbitrary_cr_registry" {
  depends_on = [
    module.eso_apikey_namespace_secretstore_1
  ]
  source                      = "../../modules/eso-external-secret"
  eso_store_scope             = "namespace"
  es_kubernetes_secret_type   = "dockerconfigjson" #checkov:skip=CKV_SECRET_6
  sm_secret_type              = "arbitrary"
  sm_secret_id                = module.sm_arbitrary_imagepull_secret.secret_id
  es_kubernetes_namespace     = kubernetes_namespace.apikey_namespaces[2].metadata[0].name
  es_container_registry       = "test.icr.com"
  es_container_registry_email = "terraform@ibm.com"
  eso_store_name              = "${var.es_namespaces_apikey[2]}-store"
  es_refresh_interval         = var.es_refresh_interval
  es_kubernetes_secret_name   = "dockerconfigjson-arb" #checkov:skip=CKV_SECRET_6
  es_helm_rls_name            = "es-docker-arb"
}
