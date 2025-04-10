##################################################################
# imported certificate for secrets manager
##################################################################

# loading from Secrets Manager the three components (private key, intermediate and public cert) composing the imported certificate
data "ibm_sm_arbitrary_secret" "imported_certificate_intermediate" {
  count       = var.imported_certificate_intermediate_secret_id != null ? 1 : 0
  region      = var.imported_certificate_sm_region
  instance_id = var.imported_certificate_sm_id
  secret_id   = var.imported_certificate_intermediate_secret_id
}

data "ibm_sm_arbitrary_secret" "imported_certificate_private" {
  count       = var.imported_certificate_private_secret_id != null ? 1 : 0
  region      = var.imported_certificate_sm_region
  instance_id = var.imported_certificate_sm_id
  secret_id   = var.imported_certificate_private_secret_id
}

data "ibm_sm_arbitrary_secret" "imported_certificate_public" {
  count       = var.imported_certificate_public_secret_id != null ? 1 : 0
  region      = var.imported_certificate_sm_region
  instance_id = var.imported_certificate_sm_id
  secret_id   = var.imported_certificate_public_secret_id
}

# composing the imported certificate
resource "ibm_sm_imported_certificate" "secrets_manager_imported_certificate" {
  count           = var.imported_certificate_public_secret_id != null && var.imported_certificate_private_secret_id != null ? 1 : 0
  instance_id     = local.sm_guid
  region          = local.sm_region
  name            = "${var.prefix}-sm-imported-cert"
  custom_metadata = { "key" : "value" }
  description     = "Imported certificate for ${var.prefix}-sm-imported-cert"
  secret_group_id = module.secrets_manager_group.secret_group_id
  certificate     = data.ibm_sm_arbitrary_secret.imported_certificate_public[0].payload
  intermediate    = var.imported_certificate_intermediate_secret_id != null ? data.ibm_sm_arbitrary_secret.imported_certificate_intermediate[0].payload : null
  private_key     = data.ibm_sm_arbitrary_secret.imported_certificate_private[0].payload
  provider        = ibm.ibm-sm
}

# definition of the flag handling the intermediate section
locals {
  imported_certificate_has_intermediate = var.imported_certificate_intermediate_secret_id != null ? true : false
}

# eso externalsecret object for imported certificate in secrets store with apikey authentication
module "external_secret_imported_certificate" {
  count = var.imported_certificate_public_secret_id != null && var.imported_certificate_private_secret_id != null ? 1 : 0
  depends_on = [
    module.eso_apikey_namespace_secretstore_1
  ]
  source                          = "../../modules/eso-external-secret"
  eso_store_scope                 = "namespace"
  es_kubernetes_secret_type       = "tls"           #checkov:skip=CKV_SECRET_6
  sm_secret_type                  = "imported_cert" #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_secret_id                    = ibm_sm_imported_certificate.secrets_manager_imported_certificate[0].secret_id
  es_kubernetes_namespace         = kubernetes_namespace.apikey_namespaces[2].metadata[0].name
  eso_store_name                  = "${var.es_namespaces_apikey[2]}-store"
  es_refresh_interval             = var.es_refresh_interval
  es_kubernetes_secret_name       = "impcertificate-tls" #tfsec:ignore:general-secrets-no-plaintext-exposure #checkov:skip=CKV_SECRET_6
  es_helm_rls_name                = "es-impcertificate"
  sm_certificate_has_intermediate = local.imported_certificate_has_intermediate
  # setting the value to false as the secret's components on SM are split in "not bundled" format
  sm_certificate_bundle = false
}
