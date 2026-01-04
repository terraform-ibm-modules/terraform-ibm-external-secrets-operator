##############################################################################
# Create ServiceID
##############################################################################

resource "ibm_iam_service_id" "image_secret_pull_service_id" {
  name        = var.service_id_name
  description = var.service_id_description
}

##############################################################################
# Create IAM policy
##############################################################################

resource "ibm_iam_service_policy" "cr_policy" {


  iam_id = ibm_iam_service_id.image_secret_pull_service_id.iam_id
  roles  = ["Reader"]

  resources {
    service           = "container-registry"
    resource_type     = "namespace"
    resource          = var.cr_namespace_name
    resource_group_id = var.resource_group_id
  }
}

# wait time to acknowledge / finish serviceID creation
resource "time_sleep" "wait_30_seconds_for_creation" {
  depends_on      = [ibm_iam_service_policy.cr_policy]
  create_duration = "30s"
}


##############################################################################
# Create Secrets-Manager IAM secret/API key
##############################################################################

module "dynamic_serviceid_apikey" {
  source  = "terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm"
  version = "1.2.19"
  region  = var.region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_iam_secret_name                = var.service_id_secret_name
  sm_iam_secret_description         = var.service_id_secret_description #tfsec:ignore:general-secrets-no-plaintext-exposure
  serviceid_id                      = ibm_iam_service_id.image_secret_pull_service_id.id
  secrets_manager_guid              = var.secrets_manager_guid
  sm_iam_secret_api_key_persistence = true
  secret_group_id                   = var.service_id_secret_group_id
  depends_on                        = [time_sleep.wait_30_seconds_for_creation]
}

## Wait 30 sec after APIKey is deleted to ensure proper processing
resource "time_sleep" "wait_30_seconds_for_destruction" {
  depends_on       = [module.dynamic_serviceid_apikey]
  destroy_duration = "30s"
}
