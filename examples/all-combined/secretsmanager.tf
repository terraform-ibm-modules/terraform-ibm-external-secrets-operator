##############################################################################
# Secrets manager validations
##############################################################################

locals {

  # validation for secrets manager region to be set for existing secrets manager instance
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

  # setting the secrets manager resource id to use
  sm_guid = var.existing_sm_instance_guid == null ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid

  # if service_endpoints is not private the crn for SM is not needed because of VPE creation is not needed
  sm_crn = var.existing_sm_instance_crn == null ? (var.service_endpoints == "private" ? ibm_resource_instance.secrets_manager[0].crn : "") : var.existing_sm_instance_crn


  sm_region  = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
  sm_acct_id = var.existing_sm_instance_guid == null ? module.iam_secrets_engine[0].acct_secret_group_id : module.secrets_manager_group_acct[0].secret_group_id
}


########################################
# Secrets-Manager and IAM configuration
########################################

# IAM user policy, Secret Manager instance, Service ID for IAM engine, IAM service ID policies, associated Service ID API key stored in a secret object in account level secret-group and IAM engine configuration
resource "ibm_resource_instance" "secrets_manager" {
  count             = var.existing_sm_instance_guid == null ? 1 : 0
  name              = "${var.prefix}-sm"
  service           = "secrets-manager"
  plan              = var.sm_service_plan
  location          = local.sm_region
  tags              = var.resource_tags
  resource_group_id = module.resource_group.resource_group_id
  timeouts {
    create = "30m" # Extending provisioning time to 30 minutes
  }
  provider = ibm.ibm-sm
}

# Configure IAM secrets engine
module "iam_secrets_engine" {
  count                                   = var.existing_sm_instance_guid == null ? 1 : 0
  source                                  = "terraform-ibm-modules/secrets-manager-iam-engine/ibm"
  version                                 = "1.2.8"
  region                                  = local.sm_region
  secrets_manager_guid                    = ibm_resource_instance.secrets_manager[0].guid
  iam_secret_generator_service_id_name    = "${var.prefix}-sid:0.0.1:${ibm_resource_instance.secrets_manager[0].name}-iam-secret-generator:automated:simple-service:secret-manager:"
  iam_secret_generator_apikey_name        = "${var.prefix}-iam-secret-generator-apikey"
  new_secret_group_name                   = "${var.prefix}-account-secret-group"
  iam_secret_generator_apikey_secret_name = "${var.prefix}-iam-secret-generator-apikey-secret"
  iam_engine_name                         = "iam-engine"
  endpoint_type                           = var.service_endpoints
  providers = {
    ibm = ibm.ibm-sm
  }
}

# create secrets group for secrets
module "secrets_manager_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.2.2"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-secret-group"                   #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group for storing account credentials" #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

# additional secrets manager secret group for service level secrets
module "secrets_manager_group_acct" {
  source               = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version              = "1.2.2"
  count                = var.existing_sm_instance_guid == null ? 0 : 1
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_group_name        = "${var.prefix}-account-secret-group"           #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group for storing account credentials" #tfsec:ignore:general-secrets-no-plaintext-exposure
  depends_on               = [module.iam_secrets_engine]
  providers = {
    ibm = ibm.ibm-sm
  }
}

##################################################################
# Create IAM serviceId, IAM policy and IAM API key to pull secrets from secret manager
##################################################################

# Create service-id
resource "ibm_iam_service_id" "secret_puller" {
  name        = "sid:0.0.1:${var.prefix}-secret-puller:automated:simple-service:secret-manager:"
  description = "ServiceID that can pull secrets from Secret Manager"
}

# Create policy to allow new service id to pull secrets from secrets manager
resource "ibm_iam_service_policy" "secret_puller_policy" {
  iam_service_id = ibm_iam_service_id.secret_puller.id
  roles          = ["Viewer", "SecretsReader"]

  resources {
    service              = "secrets-manager"
    resource_instance_id = local.sm_guid
    resource_type        = "secret-group"
    resource             = module.secrets_manager_group.secret_group_id
  }
}

# create dynamic Service ID API key and add to secret manager
module "dynamic_serviceid_apikey1" {
  source  = "terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm"
  version = "1.1.1"
  region  = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_iam_secret_name        = "${var.prefix}-${var.sm_iam_secret_name}"
  sm_iam_secret_description = "Example of dynamic IAM secret / apikey" #tfsec:ignore:general-secrets-no-plaintext-exposure
  serviceid_id              = ibm_iam_service_id.secret_puller.id
  secrets_manager_guid      = local.sm_guid
  secret_group_id           = local.sm_acct_id
  depends_on                = [module.iam_secrets_engine, ibm_iam_service_policy.secret_puller_policy, ibm_iam_service_id.secret_puller]
  providers = {
    ibm = ibm.ibm-sm
  }
}


# data source to get the API key to pull secrets from secrets manager
data "ibm_sm_iam_credentials_secret" "secret_puller_secret" {
  instance_id = local.sm_guid
  #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static type
  secret_id = module.dynamic_serviceid_apikey1.secret_id
  provider  = ibm.ibm-sm
}
