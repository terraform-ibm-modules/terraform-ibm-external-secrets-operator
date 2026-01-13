####################################################################################
# clustersecretstore with trusted profile auth
# creation of clustersecretstore, secretsgroup and externalsecrets resource
# for csecretstore supporting authentication by trusted profile
####################################################################################

# creating a secrets group for clustersecretstore with trustedprofile auth
module "tp_clusterstore_secrets_manager_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.3.36"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-cpstore-tp-secret-group"                                           #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group for storing account credentials for clusterstore tp authentication" #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

locals {
  cstore_store_name           = "cluster-store-tpauth"
  cstore_trusted_profile_name = "${var.prefix}-eso-cstore-tp"
  cstore_tp_namespace         = "eso-cstore-tp-namespace"
}

# creating trusted profiles for the secrets groups created with module tp_clusterstore_secrets_manager_group
module "external_secrets_clusterstore_trusted_profile" {
  source                          = "../../modules/eso-trusted-profile"
  trusted_profile_name            = local.cstore_trusted_profile_name
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = [module.tp_clusterstore_secrets_manager_group.secret_group_id]
  tp_cluster_crn                  = module.ocp_base.cluster_crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}

# creation of the ESO ClusterStore (cluster wide scope) with trustedprofile authentication
module "eso_clusterstore_tpauth" {
  source                            = "../../modules/eso-clusterstore"
  eso_authentication                = "trusted_profile"
  clusterstore_trusted_profile_name = local.cstore_trusted_profile_name
  region                            = local.sm_region
  clusterstore_helm_rls_name        = "${local.cstore_store_name}-rls"
  clusterstore_name                 = local.cstore_store_name
  clusterstore_secrets_manager_guid = local.sm_guid
  eso_namespace                     = var.eso_namespace
  service_endpoints                 = var.service_endpoints
  depends_on = [
    module.external_secrets_operator
  ]
}

# arbitrary secret to be synched through the clustersecretstore with TP authentication
module "sm_cstore_arbitrary_secret_tp" {
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.9.12"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.tp_clusterstore_secrets_manager_group.secret_group_id
  secret_type          = "arbitrary"
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-eso-test-dummy-secret-cstore-tp"                                      #checkov:skip=CKV_SECRET_6
  secret_description      = "eso_test_dummy_cstore_secret_tp example secret in existing secret manager instance" #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_payload_password = "dummy_secret_value_eso_test_dummy_cstore_secret_tp"                                 # pragma: allowlist secret
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Creating the namespaces for TP authentication clusterstore to store the secrets
resource "kubernetes_namespace_v1" "clusterstore_tpauth_secrets_namespace" {
  metadata {
    name = local.cstore_tp_namespace
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
  depends_on = [
    time_sleep.wait_45_seconds
  ]
}

# eso externalsecret object with clustersecretstore trusted profiles authentication
module "cstore_external_secret_tp" {
  depends_on                    = [module.eso_clusterstore_tpauth]
  source                        = "../../modules/eso-external-secret"
  eso_store_scope               = "cluster"
  es_kubernetes_namespace       = kubernetes_namespace_v1.clusterstore_tpauth_secrets_namespace.metadata[0].name
  es_kubernetes_secret_name     = "${var.prefix}-arbitrary-arb-cstore-tp"        #checkov:skip=CKV_SECRET_6
  sm_secret_type                = "arbitrary"                                    #checkov:skip=CKV_SECRET_6
  sm_secret_id                  = module.sm_cstore_arbitrary_secret_tp.secret_id #checkov:skip=CKV_SECRET_6
  es_kubernetes_secret_type     = "opaque"
  es_kubernetes_secret_data_key = "apikey"
  es_refresh_interval           = "5m"
  eso_store_name                = local.cstore_store_name # each store created with the name of the namespace with "-store" as suffix
  es_container_registry         = "us.icr.io"
  es_container_registry_email   = "user@company.com"
  es_helm_rls_name              = "es-tp"
}
