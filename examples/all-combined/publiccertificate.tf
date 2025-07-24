##################################################################
# Public certificate secret configuration
##################################################################

# A public certificate engine, consisting of a certificate authority (LetEncrypt)
# and a DNS provider authorisation (CIS) are configured as a pre-requisite to
# secrets manager generating certificates
module "secrets_manager_public_cert_engine" {
  count                                     = (var.acme_letsencrypt_private_key != null || (var.acme_letsencrypt_private_key_sm_id != null && var.acme_letsencrypt_private_key_secret_id != null && var.acme_letsencrypt_private_key_sm_region != null)) ? 1 : 0
  source                                    = "terraform-ibm-modules/secrets-manager-public-cert-engine/ibm"
  version                                   = "1.1.7"
  secrets_manager_guid                      = local.sm_guid
  region                                    = local.sm_region
  internet_services_crn                     = data.ibm_cis.cis_instance.id
  ca_config_name                            = var.ca_name != null ? var.ca_name : "${var.prefix}-project-ca"
  dns_config_name                           = var.dns_provider_name != null ? var.dns_provider_name : "${var.prefix}-project-dns"
  private_key_secrets_manager_instance_guid = var.acme_letsencrypt_private_key_sm_id
  private_key_secrets_manager_secret_id     = var.acme_letsencrypt_private_key_secret_id
  private_key_secrets_manager_region        = var.acme_letsencrypt_private_key_sm_region
  acme_letsencrypt_private_key              = var.acme_letsencrypt_private_key
  skip_iam_authorization_policy             = var.skip_iam_authorization_policy
  providers = {
    ibm              = ibm.ibm-sm
    ibm.secret-store = ibm.ibm-sm
  }
}

# public certificate common name definition
locals {
  # generating certificate common name
  cert_common_name = "pub-${var.prefix}.${var.cert_common_name}"
}

# public certificate creation
module "secrets_manager_public_certificate" {
  count                             = (var.acme_letsencrypt_private_key != null || (var.acme_letsencrypt_private_key_sm_id != null && var.acme_letsencrypt_private_key_secret_id != null && var.acme_letsencrypt_private_key_sm_region != null)) ? 1 : 0
  depends_on                        = [module.secrets_manager_public_cert_engine]
  source                            = "terraform-ibm-modules/secrets-manager-public-cert/ibm"
  version                           = "1.3.1"
  cert_common_name                  = local.cert_common_name
  cert_description                  = "Certificate for ${local.cert_common_name}"
  cert_name                         = "${var.prefix}-sm-public-cert"
  cert_secrets_group_id             = module.secrets_manager_group.secret_group_id
  secrets_manager_ca_name           = var.ca_name != null ? var.ca_name : "${var.prefix}-project-ca"
  secrets_manager_dns_provider_name = var.dns_provider_name != null ? var.dns_provider_name : "${var.prefix}-project-dns"
  secrets_manager_guid              = local.sm_guid
  secrets_manager_region            = local.sm_region
  bundle_certs                      = var.public_certificate_bundle
}

# eso externalsecret object for public certificate in secrets store with apikey authentication
module "external_secret_public_certificate" {
  count = (var.acme_letsencrypt_private_key != null || (var.acme_letsencrypt_private_key_sm_id != null && var.acme_letsencrypt_private_key_secret_id != null && var.acme_letsencrypt_private_key_sm_region != null)) ? 1 : 0
  depends_on = [
    module.eso_apikey_namespace_secretstore_1
  ]
  source                    = "../../modules/eso-external-secret"
  eso_store_scope           = "namespace"
  es_kubernetes_secret_type = "tls"         #checkov:skip=CKV_SECRET_6
  sm_secret_type            = "public_cert" #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_secret_id              = module.secrets_manager_public_certificate[0].secret_id
  es_kubernetes_namespace   = kubernetes_namespace.apikey_namespaces[2].metadata[0].name
  eso_store_name            = "${var.es_namespaces_apikey[2]}-store"
  es_refresh_interval       = var.es_refresh_interval
  es_kubernetes_secret_name = "pubcertificate-tls" #tfsec:ignore:general-secrets-no-plaintext-exposure #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "es-pubcertificate"
  sm_certificate_bundle     = var.public_certificate_bundle
}
