####################################################################################
# namespaced secretstores with trusted profile auth:
# creation of namespaces, secretstores, secretsgroups and externalsecrets resources
# for namespaced secretstores supporting authentication by trusted profiles
####################################################################################

# Create namespaces for trusted profile auth secretsstores
resource "kubernetes_namespace" "tp_namespaces" {
  count = length(var.es_namespaces_tp)
  metadata {
    name = var.es_namespaces_tp[count.index]
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

# SecretStore with trustedprofile auth for each namespace
module "eso_tp_namespace_secretstores" {
  depends_on                  = [module.external_secrets_operator]
  count                       = length(var.es_namespaces_tp)
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = "trusted_profile"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace.tp_namespaces[count.index].metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "${var.es_namespaces_tp[count.index]}-store" # each store created with the name of the namespace with "-store" as suffix
  sstore_trusted_profile_name = module.external_secrets_trusted_profiles[count.index].trusted_profile_name
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store-${count.index}"
  sstore_secret_name          = "secretstore-tp-${count.index}" #checkov:skip=CKV_SECRET_6
}

# creating a secrets group for each namespace to be used for namespaced secretstores with trustedprofile auth
module "tp_secrets_manager_groups" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.3.16"
  count                    = length(var.es_namespaces_tp)
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-tp-secret-group-${count.index}"                       #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group for storing account credentials for tp authentication" #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

# creating trusted profiles for the secrets groups created with module tp_secrets_manager_groups
module "external_secrets_trusted_profiles" {
  count                           = length(var.es_namespaces_tp)
  source                          = "../../modules/eso-trusted-profile"
  trusted_profile_name            = "${var.prefix}-eso-tp-${count.index}"
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = [module.tp_secrets_manager_groups[count.index].secret_group_id]
  tp_cluster_crn                  = module.ocp_base.cluster_crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}

# arbitrary secrets in each namespace and each related secrets group
module "sm_arbitrary_secrets_tp" {
  count                = length(var.es_namespaces_tp)
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.9.1"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.tp_secrets_manager_groups[count.index].secret_group_id
  secret_type          = "arbitrary"
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-eso-test-dummy-secret-tp-${count.index}"                       #checkov:skip=CKV_SECRET_6
  secret_description      = "eso_test_dummy_secret_tp example secret in existing secret manager instance" #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_payload_password = "dummy_secret_value_eso_test_dummy_secret_tp"                                 # pragma: allowlist secret
  providers = {
    ibm = ibm.ibm-sm
  }
}

# eso externalsecret object with trusted profiles authentication for each namespace
module "external_secret_tp" {
  depends_on = [
    module.eso_tp_namespace_secretstores
  ]
  count                         = length(var.es_namespaces_tp)
  source                        = "../../modules/eso-external-secret"
  eso_store_scope               = "namespace"
  es_kubernetes_namespace       = kubernetes_namespace.tp_namespaces[count.index].metadata[0].name
  es_kubernetes_secret_name     = "${var.prefix}-arbitrary-arb-tp-${count.index}"       #checkov:skip=CKV_SECRET_6
  sm_secret_type                = "arbitrary"                                           #checkov:skip=CKV_SECRET_6
  sm_secret_id                  = module.sm_arbitrary_secrets_tp[count.index].secret_id #checkov:skip=CKV_SECRET_6
  es_kubernetes_secret_type     = "opaque"
  es_kubernetes_secret_data_key = "apikey"
  es_refresh_interval           = "5m"
  eso_store_name                = "${var.es_namespaces_tp[count.index]}-store" # each store created with the name of the namespace with "-store" as suffix
  es_container_registry         = "us.icr.io"
  es_container_registry_email   = "user@company.com"
  es_helm_rls_name              = "es-tp"
}

######################################################################################################
# namespaced secretstores with trusted profile authentication and policy bound to multiple secrets groups
######################################################################################################

# Create namespace for tp auth with policy for multiple secrets groups
resource "kubernetes_namespace" "tp_namespace_multisg" {
  metadata {
    name = var.es_namespace_tp_multi_sg
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

# SecretStore with trustedprofile auth and TP policy bound to multiple secrets groups
module "eso_tp_namespace_secretstore_multisg" {
  depends_on                  = [module.external_secrets_operator]
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = "trusted_profile"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace.tp_namespace_multisg.metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "${var.es_namespace_tp_multi_sg}-store" # each store created with the name of the namespace with "-store" as suffix
  sstore_trusted_profile_name = module.external_secrets_trusted_profile_multisg.trusted_profile_name
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store-tp-multisg"
  sstore_secret_name          = "secretstore-tp-multisg" #checkov:skip=CKV_SECRET_6
}

# creating two secrets groups for a single namespace to test trusted profile policy on multiple secrets groups
module "tp_secrets_manager_group_multi_1" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.3.16"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-tp-secret-group-multisg-1"                                                                #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group n.1 for storing account credentials for tp authentication with multi secrets group policy" #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

module "tp_secrets_manager_group_multi_2" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.3.16"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-tp-secret-group-multisg-21"                                                               #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group n.2 for storing account credentials for tp authentication with multi secrets group policy" #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

# arbitrary secret for secrets group 1
module "sm_arbitrary_secret_tp_multisg_1" {
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.9.1"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.tp_secrets_manager_group_multi_1.secret_group_id
  secret_type          = "arbitrary"
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-eso-test-dummy-secret-tp-multisg-1"                                                                        #checkov:skip=CKV_SECRET_6
  secret_description      = "eso_test_dummy_secret_tp_multisg_1 example secret in existing secret manager instance for tp auth for secrets group n.1" #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_payload_password = "dummy_secret_value_eso_test_dummy_secret_tp"                                                                             # pragma: allowlist secret
  providers = {
    ibm = ibm.ibm-sm
  }
}

# arbitrary secret for secrets group 2
module "sm_arbitrary_secret_tp_multisg_2" {
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.9.1"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.tp_secrets_manager_group_multi_2.secret_group_id
  secret_type          = "arbitrary"
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-eso-test-dummy-secret-tp-multisg-2"                                                                        #checkov:skip=CKV_SECRET_6
  secret_description      = "eso_test_dummy_secret_tp_multisg_2 example secret in existing secret manager instance for tp auth for secrets group n.2" #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_payload_password = "dummy_secret_value_eso_test_dummy_secret_tp"                                                                             # pragma: allowlist secret
  providers = {
    ibm = ibm.ibm-sm
  }
}

# creating trusted profile with TP policy bound to multiple secrets groups
module "external_secrets_trusted_profile_multisg" {
  source                          = "../../modules/eso-trusted-profile"
  trusted_profile_name            = "${var.prefix}-eso-tp-multisg"
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = [module.tp_secrets_manager_group_multi_1.secret_group_id, module.tp_secrets_manager_group_multi_2.secret_group_id]
  tp_cluster_crn                  = module.ocp_base.cluster_crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}

# first eso externalsecret object with trusted profile authentication and TP policy bound to multiple secrets groups
module "external_secret_tp_multisg_1" {
  depends_on = [
    module.eso_tp_namespace_secretstore_multisg
  ]
  source                        = "../../modules/eso-external-secret"
  eso_store_scope               = "namespace"
  es_kubernetes_namespace       = kubernetes_namespace.tp_namespace_multisg.metadata[0].name
  es_kubernetes_secret_name     = "${var.prefix}-arbitrary-arb-tp-multisg-1"        #checkov:skip=CKV_SECRET_6
  sm_secret_type                = "arbitrary"                                       #checkov:skip=CKV_SECRET_6
  sm_secret_id                  = module.sm_arbitrary_secret_tp_multisg_1.secret_id #checkov:skip=CKV_SECRET_6
  es_kubernetes_secret_type     = "opaque"
  es_kubernetes_secret_data_key = "apikey"
  es_refresh_interval           = "5m"
  eso_store_name                = "${var.es_namespace_tp_multi_sg}-store" # each store created with the name of the namespace with "-store" as suffix
  es_container_registry         = "us.icr.io"
  es_container_registry_email   = "user@company.com"
  es_helm_rls_name              = "es-tp-multisg-1"
}

# second eso externalsecret object with trusted profile authentication and TP policy bound to multiple secrets groups
module "external_secret_tp_multisg_2" {
  depends_on = [
    module.eso_tp_namespace_secretstore_multisg
  ]
  source                        = "../../modules/eso-external-secret"
  eso_store_scope               = "namespace"
  es_kubernetes_namespace       = kubernetes_namespace.tp_namespace_multisg.metadata[0].name
  es_kubernetes_secret_name     = "${var.prefix}-arbitrary-arb-tp-multisg-2"        #checkov:skip=CKV_SECRET_6
  sm_secret_type                = "arbitrary"                                       #checkov:skip=CKV_SECRET_6
  sm_secret_id                  = module.sm_arbitrary_secret_tp_multisg_2.secret_id #checkov:skip=CKV_SECRET_6
  es_kubernetes_secret_type     = "opaque"
  es_kubernetes_secret_data_key = "apikey"
  es_refresh_interval           = "5m"
  eso_store_name                = "${var.es_namespace_tp_multi_sg}-store" # each store created with the name of the namespace with "-store" as suffix
  es_container_registry         = "us.icr.io"
  es_container_registry_email   = "user@company.com"
  es_helm_rls_name              = "es-tp-multisg-2"
}

######################################################################################################
# namespaced secretstores with trusted profile authentication and policy not bound to any secrets group
######################################################################################################

# Create namespace for trusted profile authentication with policy without secrets group
resource "kubernetes_namespace" "tp_namespace_tpnosg" {
  metadata {
    name = var.es_namespace_tp_no_sg
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

# SecretStore with trusted profile authentication and TP policy without secrets group
module "eso_tp_namespace_secretstore_nosecgroup" {
  depends_on                  = [module.external_secrets_operator]
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = "trusted_profile"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace.tp_namespace_tpnosg.metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "${var.es_namespace_tp_no_sg}-store" # each store created with the name of the namespace with "-store" as suffix
  sstore_trusted_profile_name = module.external_secrets_trusted_profile_nosecgroup.trusted_profile_name
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store-tp-nosg"
  sstore_secret_name          = "secretstore-tp-nosg" #checkov:skip=CKV_SECRET_6
}

# creating secrets group for a single namespace to test trusted profile policy without any secret group in the TP policy
module "tp_secrets_manager_group_not_for_policy" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.3.16"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-tp-secret-group-not-for-policy"                                                        #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group for storing account credentials for tp authentication not to be added to the TP policy" #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

# arbitrary secret to use with external secret with auth using TP and policy not restricted to secrets group
module "sm_arbitrary_secret_tp_nosecgroup" {
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.9.1"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.tp_secrets_manager_group_not_for_policy.secret_group_id
  secret_type          = "arbitrary"
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-eso-test-dummy-secret-tp-nosecgroup"                                                                                     #checkov:skip=CKV_SECRET_6
  secret_description      = "eso_test_dummy_secret_tp_nosecgroup example secret in existing secret manager instance for tp auth for secrets group not in TP policy" #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_payload_password = "dummy_secret_value_eso_test_dummy_secret_tp"                                                                                           # pragma: allowlist secret
  providers = {
    ibm = ibm.ibm-sm
  }
}

# creating trusted profile with policy not restricted to secrets groups
module "external_secrets_trusted_profile_nosecgroup" {
  source                          = "../../modules/eso-trusted-profile"
  trusted_profile_name            = "${var.prefix}-eso-tp-nosecgroup"
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = []
  tp_cluster_crn                  = module.ocp_base.cluster_crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}

# eso externalsecret object with trusted profile authentication without secrects group in the policy
module "external_secret_tp_nosg" {
  depends_on = [
    module.eso_tp_namespace_secretstore_nosecgroup
  ]
  source                        = "../../modules/eso-external-secret"
  eso_store_scope               = "namespace"
  es_kubernetes_namespace       = kubernetes_namespace.tp_namespace_tpnosg.metadata[0].name
  es_kubernetes_secret_name     = "${var.prefix}-arbitrary-arb-tp-nosg"              #checkov:skip=CKV_SECRET_6
  sm_secret_type                = "arbitrary"                                        #checkov:skip=CKV_SECRET_6
  sm_secret_id                  = module.sm_arbitrary_secret_tp_nosecgroup.secret_id #checkov:skip=CKV_SECRET_6
  es_kubernetes_secret_type     = "opaque"
  es_kubernetes_secret_data_key = "apikey"
  es_refresh_interval           = "5m"
  eso_store_name                = "${var.es_namespace_tp_no_sg}-store" # each store created with the name of the namespace with "-store" as suffix
  es_container_registry         = "us.icr.io"
  es_container_registry_email   = "user@company.com"
  es_helm_rls_name              = "es-tp-nosg"
}
