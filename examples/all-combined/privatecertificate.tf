##################################################################
# Private certificate secret configuration
##################################################################

# private certificate common name, Certificate Authority common name and certificate template name definition
locals {
  # generating certificate common name
  pvt_cert_common_name          = "pvt-${var.prefix}.${var.pvt_cert_common_name}"
  pvt_root_ca_common_name       = "pvt-${var.prefix}.${var.pvt_root_ca_common_name}"
  pvt_certificate_template_name = var.pvt_certificate_template_name != null ? var.pvt_certificate_template_name : "pvt-${var.prefix}-cert-template"
}

# private certificate engine
module "secrets_manager_private_secret_engine" {
  source                    = "terraform-ibm-modules/secrets-manager-private-cert-engine/ibm"
  version                   = "1.13.1"
  secrets_manager_guid      = local.sm_guid
  region                    = local.sm_region
  root_ca_name              = var.pvt_ca_name != null ? var.pvt_ca_name : "pvt-${var.prefix}-project-root-ca"
  root_ca_common_name       = local.pvt_root_ca_common_name
  root_ca_max_ttl           = var.pvt_ca_max_ttl
  intermediate_ca_name      = "pvt-${var.prefix}-project-intermediate-ca"
  certificate_template_name = local.pvt_certificate_template_name
  providers = {
    ibm = ibm.ibm-sm
  }
}

# private certificate generation
module "secrets_manager_private_certificate" {
  depends_on             = [module.secrets_manager_private_secret_engine]
  source                 = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version                = "1.11.1"
  cert_name              = "${var.prefix}-sm-private-cert"
  cert_description       = "Private certificate for ${local.pvt_cert_common_name}"
  cert_secrets_group_id  = module.secrets_manager_group.secret_group_id
  cert_template          = local.pvt_certificate_template_name
  cert_common_name       = local.pvt_cert_common_name
  secrets_manager_guid   = local.sm_guid
  secrets_manager_region = local.sm_region
  providers = {
    ibm = ibm.ibm-sm
  }
}

# eso externalsecret object for private certificate in secrets store with apikey authentication
module "external_secret_private_certificate" {
  depends_on = [
    module.eso_apikey_namespace_secretstore_1
  ]
  source                    = "../../modules/eso-external-secret"
  eso_store_scope           = "namespace"
  es_kubernetes_secret_type = "tls"          #checkov:skip=CKV_SECRET_6
  sm_secret_type            = "private_cert" #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_secret_id              = module.secrets_manager_private_certificate.secret_id
  es_kubernetes_namespace   = kubernetes_namespace_v1.apikey_namespaces[2].metadata[0].name
  eso_store_name            = "${var.es_namespaces_apikey[2]}-store"
  es_refresh_interval       = var.es_refresh_interval
  es_kubernetes_secret_name = "pvtcertificate-tls" #tfsec:ignore:general-secrets-no-plaintext-exposure #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "es-pvtcertificate"
}
