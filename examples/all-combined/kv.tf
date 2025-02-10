##################################################################
# Management of kv secrets
##################################################################

##################################################################
# Single key kv secret
##################################################################

resource "ibm_sm_kv_secret" "secrets_manager_kv_secret_singlekey" {
  instance_id     = local.sm_guid
  region          = local.sm_region
  custom_metadata = { "meta_key" : "meta_value" }
  data            = { "secret_key" : "secret_value" }
  description     = "Extended description for this secret."
  labels          = ["my-label"]
  secret_group_id = module.secrets_manager_group.secret_group_id
  name            = "${var.prefix}-sm-kv-secret"
  provider        = ibm.ibm-sm
}

##################################################################
# Multiple keys kv secret
##################################################################

resource "ibm_sm_kv_secret" "secrets_manager_kv_secret_multiplekeys" {
  instance_id     = local.sm_guid
  region          = local.sm_region
  custom_metadata = { "meta_key" : "meta_value" }
  data            = { "secret_key1" : "secret_value1", "secret_key2" : "secret_value2", "secret_key3" : "secret_value3" } # checkov:skip=CKV_SECRET_6
  description     = "Extended description for this secret."
  labels          = ["my-label"]
  secret_group_id = module.secrets_manager_group.secret_group_id
  name            = "${var.prefix}-sm-kv-multikeys-secret"
  provider        = ibm.ibm-sm
}

# eso externalsecret object for single key kv secret configured with apikey authentication secretstore
module "external_secret_kv_singlekey" {
  depends_on = [
    module.eso_apikey_namespace_secretstore_2
  ]
  source                    = "../../modules/eso-external-secret"
  eso_store_scope           = "namespace"
  es_kubernetes_secret_type = "opaque" #checkov:skip=CKV_SECRET_6
  sm_secret_type            = "kv"     #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_secret_id              = ibm_sm_kv_secret.secrets_manager_kv_secret_singlekey.secret_id
  es_kubernetes_namespace   = kubernetes_namespace.apikey_namespaces[3].metadata[0].name
  eso_store_name            = "${var.es_namespaces_apikey[3]}-store"
  es_refresh_interval       = var.es_refresh_interval
  es_kubernetes_secret_name = "kv-single-key" #tfsec:ignore:general-secrets-no-plaintext-exposure #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "kv-single-key"
  sm_kv_keyid               = "secret_key"
}

# eso externalsecret object for multiple keys kv secret configured with apikey authentication secretstore
module "external_secret_kv_multiplekeys" {
  depends_on = [
    module.eso_apikey_namespace_secretstore_2
  ]
  source                    = "../../modules/eso-external-secret"
  eso_store_scope           = "namespace"
  es_kubernetes_secret_type = "opaque" #checkov:skip=CKV_SECRET_6
  sm_secret_type            = "kv"     #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_secret_id              = ibm_sm_kv_secret.secrets_manager_kv_secret_multiplekeys.secret_id
  es_kubernetes_namespace   = kubernetes_namespace.apikey_namespaces[3].metadata[0].name
  eso_store_name            = "${var.es_namespaces_apikey[3]}-store"
  es_refresh_interval       = var.es_refresh_interval
  es_kubernetes_secret_name = "kv-multiple-keys" #tfsec:ignore:general-secrets-no-plaintext-exposure #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "kv-multiple-keys"
}
