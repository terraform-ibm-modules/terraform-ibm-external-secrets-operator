##############################################################################
# Load cluster and serviceID details
##############################################################################

# data "ibm_iam_service_id" "existing_sdnlb_serviceid" {
#   name = var.existing_sdnlb_serviceid_name
# }

# creating a dynamic secret on SM to generate the serviceID API key
# module "dynamic_sdnlb_serviceid_apikey_by_sm_serviceid_apikey" {
#   source                    = "terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm"
#   version                   = "1.1.1"
#   region                    = local.sm_region
#   sm_iam_secret_name        = "${var.prefix}-sdnlb-secret"
#   sm_iam_secret_description = "sdnlb serviceID apikey secret"
#   secrets_manager_guid      = local.sm_guid
#   serviceid_id              = data.ibm_iam_service_id.existing_sdnlb_serviceid.service_ids[0].id
#   secret_group_id           = module.secrets_manager_group.secret_group_id
#   providers = {
#     ibm = ibm.ibm-sm
#   }
# }

# module "sdnlb_eso_secret" {
#   depends_on          = [module.external_secrets_operator]
#   source              = "git::https://github.ibm.com/GoldenEye/sdnlb-module.git//modules/sdnlb-eso-secret-module?ref=3.5.0"
#   sdnlb_service_id    = data.ibm_iam_service_id.existing_sdnlb_serviceid.service_ids[0].id
#   sdnlb_api_key_sm_id = module.dynamic_sdnlb_serviceid_apikey_by_sm_serviceid_apikey.secret_id
#   #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static type
#   externalsecret_helm_release_new_namespace = "sdnlb-secret-helm-release-namespace"
#   eso_store_name                            = "cluster-store"
#   eso_store_scope                           = "cluster"

#   providers = {
#     ibm = ibm.ibm-sdnlb
#   }
# }
