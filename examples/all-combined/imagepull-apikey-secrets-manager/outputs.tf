##############################################################################
# Outputs
##############################################################################

output "secret_manager_guid" {
  value       = var.secrets_manager_guid
  description = "GUI of Secrets-Manager containing secret"
}

output "serviceid_name" {
  description = "Name of the ServiceID created to access Container Registry"
  value       = ibm_iam_service_id.image_secret_pull_service_id.name
}

output "serviceid_apikey_secret_id" {
  description = "ID of the Secret Manager Secret containing ServiceID API Key"
  value       = module.dynamic_serviceid_apikey.secret_id
}
