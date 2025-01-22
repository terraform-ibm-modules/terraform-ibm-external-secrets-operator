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

##################################################################
# Image pull API key secret using imagepull-apikey-secrets-manager-module
##################################################################

# create image pull serviceID and secret and store in secrets manager
module "image_pull" {
  source               = "../../modules/imagepull-apikey-secrets-manager-module"
  resource_group_id    = module.resource_group.resource_group_id
  secrets_manager_guid = local.sm_guid
  cr_namespace_name    = var.cr_namespace_name
  region               = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  service_id_secret_name     = "${var.prefix}-image-pull-service-id"
  service_id_secret_group_id = module.secrets_manager_group.secret_group_id
  depends_on                 = [module.iam_secrets_engine, module.secrets_manager_group]
  providers = {
    ibm = ibm.ibm-sm
  }
}

# ESO external secret storing the secret in the cluster as dockerconfigson type (from image pull IAM dynamic credential/secret) using namespaced secretstore
module "external_secret_secret_image_pull" {
  source = "../../modules/eso-external-secret"
  depends_on = [
    module.eso_apikey_namespace_secretstore_2,
  ]
  eso_store_scope             = "namespace"
  es_kubernetes_secret_type   = "dockerconfigjson" #checkov:skip=CKV_SECRET_6
  sm_secret_type              = "iam_credentials"  #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_secret_id                = module.image_pull.serviceid_apikey_secret_id
  es_kubernetes_namespace     = kubernetes_namespace.apikey_namespaces[3].metadata[0].name
  es_container_registry       = "test.icr.com"
  es_container_registry_email = "terraform@ibm.com"
  es_refresh_interval         = var.es_refresh_interval
  eso_store_name              = "${var.es_namespaces_apikey[3]}-store"
  es_kubernetes_secret_name   = "dockerconfigjson-iam" #tfsec:ignore:general-secrets-no-plaintext-exposure #checkov:skip=CKV_SECRET_6
  es_helm_rls_name            = "es-docker-iam"
}

##################################################################
# Image pull API key secrets using imagepull-apikey-secrets-manager-module
# to be configured in a single chain of secrets
##################################################################

# create image pull serviceID and secret and store in secrets manager
module "image_pull_chain_secret_1" {
  source               = "../../modules/imagepull-apikey-secrets-manager-module"
  resource_group_id    = module.resource_group.resource_group_id
  secrets_manager_guid = local.sm_guid
  cr_namespace_name    = var.cr_namespace_name
  region               = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  service_id_secret_name     = "${var.prefix}-image-pull-service-id-chain-sec-1"
  service_id_secret_group_id = module.secrets_manager_group.secret_group_id
  depends_on                 = [module.iam_secrets_engine, module.secrets_manager_group]
  providers = {
    ibm = ibm.ibm-sm
  }
}

# create image pull serviceID and secret and store in secrets manager
module "image_pull_chain_secret_2" {
  source               = "../../modules/imagepull-apikey-secrets-manager-module"
  resource_group_id    = module.resource_group.resource_group_id
  secrets_manager_guid = local.sm_guid
  cr_namespace_name    = var.cr_namespace_name
  region               = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  service_id_secret_name     = "${var.prefix}-image-pull-service-id-chain-sec-2"
  service_id_secret_group_id = module.secrets_manager_group.secret_group_id
  depends_on                 = [module.iam_secrets_engine, module.secrets_manager_group]
  providers = {
    ibm = ibm.ibm-sm
  }
}

# create image pull serviceID and secret and store in secrets manager
module "image_pull_chain_secret_3" {
  source               = "../../modules/imagepull-apikey-secrets-manager-module"
  resource_group_id    = module.resource_group.resource_group_id
  secrets_manager_guid = local.sm_guid
  cr_namespace_name    = var.cr_namespace_name
  region               = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  service_id_secret_name     = "${var.prefix}-image-pull-service-id-chain-sec-3"
  service_id_secret_group_id = module.secrets_manager_group.secret_group_id
  depends_on                 = [module.iam_secrets_engine, module.secrets_manager_group]
  providers = {
    ibm = ibm.ibm-sm
  }
}

module "external_secret_secret_image_pull_chain" {
  source                    = "../../modules/eso-external-secret"
  depends_on                = [module.eso_apikey_namespace_secretstore_2, ]
  eso_store_scope           = "namespace"
  es_kubernetes_secret_type = "dockerconfigjson"
  sm_secret_type            = "iam_credentials"
  eso_store_name            = "${var.es_namespaces_apikey[3]}-store"
  es_kubernetes_secret_name = "dockerconfigjson-chain"
  es_helm_rls_name          = "es-docker-iam-chain"
  es_kubernetes_namespace   = kubernetes_namespace.apikey_namespaces[3].metadata[0].name
  sm_secret_id              = null # null is accepted only in the case of a dockerjsonconfig secret with secrets chain
  es_container_registry_secrets_chain = [
    {
      "es_container_registry" : "test1.icr.com", "sm_secret_id" : module.image_pull_chain_secret_1.serviceid_apikey_secret_id, "es_container_registry_email" : "terraform1@ibm.com"
    },
    {
      "es_container_registry" : "test2.icr.com", "sm_secret_id" : module.image_pull_chain_secret_2.serviceid_apikey_secret_id, "es_container_registry_email" : null
    },
    {
      "es_container_registry" : "test3.icr.com", "sm_secret_id" : module.image_pull_chain_secret_3.serviceid_apikey_secret_id, "es_container_registry_email" : ""
    }
  ]
}
