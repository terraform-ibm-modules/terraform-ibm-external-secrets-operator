##############################################################################
# Outputs
##############################################################################

# output "secret_manager_guid" {
#   value       = module.image_pull.secret_manager_guid
#   description = "GUID of Secrets-Manager containing secret"
# }

# output "serviceid_name" {
#   description = "Name of the ServiceID created to access Container Registry"
#   value       = module.image_pull.serviceid_name
# }

# output "serviceid_apikey_secret_id" {
#   description = "ID of the Secret Manager Secret containing ServiceID API Key"
#   value       = module.image_pull.serviceid_apikey_secret_id
# }

output "cluster_id" {
  description = "ID of the cluster deployed"
  value       = module.ocp_base.cluster_id
}
