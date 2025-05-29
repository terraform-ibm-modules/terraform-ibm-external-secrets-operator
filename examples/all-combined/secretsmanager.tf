##############################################################################
# Secrets manager validations
##############################################################################

locals {
  # setting the secrets manager resource id to use
  sm_guid = var.existing_sm_instance_guid == null ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid

  # if service_endpoints is not private the crn for SM is not needed because of VPE creation is not needed
  sm_crn = var.existing_sm_instance_crn == null ? (var.service_endpoints == "private" ? ibm_resource_instance.secrets_manager[0].crn : "") : var.existing_sm_instance_crn


  sm_region = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
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

# create secrets group for secrets
module "secrets_manager_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.3.7"
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
  version              = "1.3.7"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_group_name        = "${var.prefix}-account-secret-group"           #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "Secret-Group for storing account credentials" #tfsec:ignore:general-secrets-no-plaintext-exposure
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
  version = "1.2.0"
  region  = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_iam_secret_name        = "${var.prefix}-${var.sm_iam_secret_name}"
  sm_iam_secret_description = "Example of dynamic IAM secret / apikey" #tfsec:ignore:general-secrets-no-plaintext-exposure
  serviceid_id              = ibm_iam_service_id.secret_puller.id
  secrets_manager_guid      = local.sm_guid
  secret_group_id           = module.secrets_manager_group_acct.secret_group_id
  depends_on                = [ibm_iam_service_policy.secret_puller_policy, ibm_iam_service_id.secret_puller]
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
