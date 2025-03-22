module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.1.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

locals {
  sm_service_plan              = "trial"
  trusted_profile_name         = "${var.prefix}-eso-tp"
  secret_manager_instance_name = "${var.prefix}-sm-instance"                            #checkov:skip=CKV_SECRET_6
  secret_group_name            = "${var.prefix}-sm-secret-group"                        #checkov:skip=CKV_SECRET_6
  es_kubernetes_namespaces     = ["${var.prefix}-tp-test-1", "${var.prefix}-tp-test-2"] # namespace to create the externalsecrets resources for secrets sync

  validate_sm_region_cnd = var.existing_sm_instance_guid != null && var.existing_sm_instance_region == null
  validate_sm_region_msg = "existing_sm_instance_region must also be set when value given for existing_sm_instance_guid."
  # tflint-ignore: terraform_unused_declarations
  validate_sm_region_chk = regex(
    "^${local.validate_sm_region_msg}$",
    (!local.validate_sm_region_cnd
      ? local.validate_sm_region_msg
  : ""))

  # validation for secrets manager crn to be set for existing secrets manager instance if using private service endpoints
  validate_sm_crn_cnd = var.existing_sm_instance_guid != null && var.existing_sm_instance_crn == null && var.service_endpoints == "private"
  validate_sm_crn_msg = "existing_sm_instance_crn must also be set when value given for existing_sm_instance_guid if service_endpoints is private."
  # tflint-ignore: terraform_unused_declarations
  validate_sm_crn_chk = regex(
    "^${local.validate_sm_crn_msg}$",
    (!local.validate_sm_crn_cnd
      ? local.validate_sm_crn_msg
  : ""))

  sm_guid = var.existing_sm_instance_guid == null ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid
  # if service_endpoints is not private the crn for SM is not needed because of VPE creation is not needed
  sm_crn = var.existing_sm_instance_crn == null ? (var.service_endpoints == "private" ? ibm_resource_instance.secrets_manager[0].crn : "") : var.existing_sm_instance_crn

  sm_region = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region

}

##############################################################################
## Create prerequisite.  Secrets Manager,  Secret Group and a Trusted Profile
##############################################################################

resource "ibm_resource_instance" "secrets_manager" {
  count             = var.existing_sm_instance_guid == null ? 1 : 0
  name              = local.secret_manager_instance_name
  service           = "secrets-manager"
  plan              = local.sm_service_plan
  location          = local.sm_region
  resource_group_id = module.resource_group.resource_group_id
  timeouts {
    create = "20m" # Extending provisioning time to 20 minutes
  }
}

## Secret Group for organizing secrets

module "secrets_manager_groups" {
  source               = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version              = "1.2.3"
  count                = length(kubernetes_namespace.examples)
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_group_name        = "${local.secret_group_name}_${count.index}"
  secret_group_description = "secret ${count.index} used for examples" #tfsec:ignore:general-secrets-no-plaintext-exposure
}

# We retrieve metadata of the cluster to get the cluster's CRN.
# The CRN then will be used in the Trusted Profile Rule
data "ibm_container_vpc_cluster" "cluster" {
  name = var.cluster_name_id
}

##################################################################
## Example creating two arbitrary dummy secrets for test
##################################################################

# creating the namespace to create the ES resources and the dummy secrets
resource "kubernetes_namespace" "examples" {
  count = length(local.es_kubernetes_namespaces)
  metadata {
    name = local.es_kubernetes_namespaces[count.index]
  }
}

module "sm_arbitrary_secrets" {
  count                = length(kubernetes_namespace.examples)
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.7.0"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = module.secrets_manager_groups[count.index].secret_group_id
  secret_type          = "arbitrary"
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${var.prefix}-eso-test-dummy-secret-${count.index}"                  #checkov:skip=CKV_SECRET_6
  secret_description      = "# ${count.index} example secret in existing secret manager instance" #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_payload_password = "dummy_secret_value_${count.index}"                                   # pragma: allowlist secret
}

# creating trusted profiles
module "external_secrets_trusted_profiles" {
  count                           = length(kubernetes_namespace.examples)
  source                          = "../../modules/eso-trusted-profile"
  trusted_profile_name            = "${local.trusted_profile_name}_${count.index}"
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = [module.secrets_manager_groups[count.index].secret_group_id]
  tp_cluster_crn                  = data.ibm_container_vpc_cluster.cluster.crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}

########################################################################
## Deploying ESO
########################################################################

module "external_secrets_operator" {
  source        = "../../"
  eso_namespace = var.eso_namespace
  eso_cluster_nodes_configuration = var.eso_deployment_nodes_configuration == null ? null : {
    nodeSelector = {
      label = "dedicated"
      value = var.eso_deployment_nodes_configuration
    }
    tolerations = {
      key      = "dedicated"
      operator = "Equal"
      value    = var.eso_deployment_nodes_configuration
      effect   = "NoExecute"
    }
  }
}

########################################################################
## Deploying ESO SecretStores
########################################################################

module "eso_namespace_secretstores" {
  count = length(kubernetes_namespace.examples)
  depends_on = [
    module.external_secrets_operator
  ]
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = "trusted_profile"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace.examples[count.index].metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "${kubernetes_namespace.examples[count.index].metadata[0].name}-store" # each store created with the name of the namespace with "-store" as suffix
  sstore_trusted_profile_name = module.external_secrets_trusted_profiles[count.index].trusted_profile_name
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store-${count.index}"
  sstore_secret_name          = "secretstore-api-key" #checkov:skip=CKV_SECRET_6
}

######################################
# creating eso externalsecret objects
######################################

module "external_secrets" {
  depends_on = [
    module.eso_namespace_secretstores
  ]
  count                         = length(kubernetes_namespace.examples)
  source                        = "../../modules/eso-external-secret"
  eso_store_scope               = "namespace"
  es_kubernetes_namespace       = kubernetes_namespace.examples[count.index].metadata[0].name
  es_kubernetes_secret_name     = "${var.prefix}-arbitrary-arb-${count.index}"       #checkov:skip=CKV_SECRET_6
  sm_secret_type                = "arbitrary"                                        #checkov:skip=CKV_SECRET_6
  sm_secret_id                  = module.sm_arbitrary_secrets[count.index].secret_id #checkov:skip=CKV_SECRET_6
  es_kubernetes_secret_type     = "opaque"
  es_kubernetes_secret_data_key = "apikey"
  es_refresh_interval           = "5m"
  eso_store_name                = "${kubernetes_namespace.examples[count.index].metadata[0].name}-store" # each store created with the name of the namespace with "-store" as suffix
  es_container_registry         = "us.icr.io"
  es_container_registry_email   = "user@company.com"
  es_helm_rls_name              = "es-${count.index}"
}

######################################
# creating VPEs
######################################

module "vpes" {
  source   = "terraform-ibm-modules/vpe-gateway/ibm"
  version  = "4.5.0"
  count    = var.service_endpoints == "private" ? 1 : 0
  region   = var.region
  prefix   = "vpe"
  vpc_name = var.vpe_vpc_name
  vpc_id   = var.vpe_vpc_id
  subnet_zone_list = [
    for index, subnet in var.vpe_vpc_subnets : {
      name           = "${var.region}-${index}"
      zone           = "${var.region}-${index}"
      id             = subnet
      acl_name       = "acl"
      public_gateway = true
    }
  ]
  resource_group_id  = var.vpe_vpc_resource_group_id # pragma: allowlist secret
  security_group_ids = [var.vpe_vpc_security_group_id]
  cloud_services     = []
  cloud_service_by_crn = [
    {
      name = "iam-${var.region}"
      crn  = "crn:v1:bluemix:public:iam-svcs:global:::endpoint:private.iam.cloud.ibm.com"
    },
    {
      name = "sm-${var.region}"
      crn  = local.sm_crn
    }
  ]
  service_endpoints = "private"
}
