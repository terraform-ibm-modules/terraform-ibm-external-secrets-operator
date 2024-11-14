######## eso clusterstore configuration

variable "eso_namespace" {
  description = "Namespace where the ESO is deployed. It will be used to deploy the ClusterStore"
  type        = string
}

variable "region" {
  description = "Region where Secrets Manager is deployed. It will be used to build the regional URL to the service"
  type        = string
}

variable "service_endpoints" {
  type        = string
  description = "The service endpoint type to communicate with the provided secrets manager instance. Possible values are `public` or `private`. This also will set the iam endpoint for containerAuth when enabling Trusted Profile/CR based authentication."
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.service_endpoints)
    error_message = "The specified service_endpoints is not a valid selection!"
  }
}

variable "clusterstore_name" {
  description = "Name of the ESO secret store to be used/created for cluster scope."
  default     = "clustersecret-store"
  type        = string
}

variable "clusterstore_helm_rls_name" {
  description = "Name of helm release for clusterstore"
  type        = string
  default     = "cluster-secret-store"
}

##############################################################################
# Authentication configuration for clusterstore that can be one of api_key or trusted_profile
##############################################################################
variable "eso_authentication" {
  type        = string
  description = "Authentication method, Possible values are api_key or/and trusted_profile."
  default     = "trusted_profile"
  validation {
    condition     = contains(["api_key", "trusted_profile"], var.eso_authentication)
    error_message = "Authentication mode allowed are api_key or/and trusted_profile."
  }
}

variable "clusterstore_secret_name" {
  description = "Secret name to be used/referenced in the ESO clusterstore to pull from Secrets Manager"
  default     = "ibm-secret"
  type        = string
}

variable "clusterstore_secret_apikey" {
  type        = string
  description = "APIkey to be configured in the clusterstore_secret_name secret in the ESO clusterstore. One between clusterstore_secret_apikey and clusterstore_trusted_profile_name must be filled"
  sensitive   = true
  default     = null
}

####### trusted profile

variable "clusterstore_trusted_profile_name" {
  type        = string
  description = "The name of the trusted profile to use for clusterstore scope. This allows ESO to use CRI based authentication to access secrets manager. The trusted profile must be created in advance"
  default     = null
}

####### Secrets Manager instance

variable "clusterstore_secrets_manager_guid" {
  type        = string
  description = "Secrets manager instance GUID for clusterstore where secrets will be stored or fetched from"
}
