# cluster secrets store created resources

output "cluster_secrets_stores_service_secrets_groups" {
    description = "Secrets groups created for each cluster secrets store to store the secrets managed through by ESO"
    value = local.cluster_secrets_stores_service_secrets_groups
}

output "cluster_secrets_stores_account_secrets_groups" {
   description = "Secrets groups created for each cluster secrets store and used by this to managed the store secrets"
   value = local.cluster_secrets_stores_account_secrets_groups
}

output "cluster_secrets_stores_secret_puller_service_ids" {
    description = "ServiceIDs created for each cluster secrets store to pull secrets from Secrets Manager"
    value = local.cluster_secrets_stores_secret_puller_service_ids
}

output "cluster_secrets_store_account_serviceid_apikey_secrets" {
    description = "Secrets Manager secret created for each cluster secrets store and the related serviceID for the API key to pull secrets from Secrets Manager"
    value = local.cluster_secrets_store_account_serviceid_apikey_secrets
}

# secrets store created resources

output "secrets_stores_service_secrets_groups" {
    description = "Secrets groups created for each secrets store to store the secrets managed through by ESO"
    value = local.secrets_stores_service_secrets_groups
}

output "secrets_stores_account_secrets_groups" {
    description = "Secrets groups created for each secrets store and used by this to managed the store secrets"
    value = local.secrets_stores_account_secrets_groups
}

output "secrets_stores_secret_puller_service_ids" {
    description = "ServiceIDs created for each secrets store to pull secrets from Secrets Manager"
    value = local.secrets_stores_secret_puller_service_ids
}

output "secrets_store_account_serviceid_apikey_secrets" {
    description = "Secrets Manager secret created for each secrets store and the related serviceID for the API key to pull secrets from Secrets Manager"
    value = local.secrets_store_account_serviceid_apikey_secrets
}