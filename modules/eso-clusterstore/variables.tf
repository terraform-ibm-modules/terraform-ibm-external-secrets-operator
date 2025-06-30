######## eso clusterstore configuration

variable "eso_namespace" {
  description = "Namespace where the ESO is deployed. It will be used to deploy the cluster secrets store"
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
    error_message = "The value for var.service_endpoints must be either public or private."
  }
}

variable "clusterstore_name" {
  description = "Name of the ESO cluster secrets store to be used/created for cluster scope."
  default     = "clustersecret-store"
  type        = string
  validation {
    condition     = can(regex("^([a-z][-a-z0-9]*[a-z0-9])$", var.clusterstore_name))
    error_message = "The cluster secrets store name must start with a lowercase letter, can contain lowercase letters, numbers and hyphens, and must end with a lowercase letter."
  }
}

variable "clusterstore_helm_rls_name" {
  description = "Name of helm release for cluster secrets store"
  type        = string
  default     = "cluster-secret-store"
}

##############################################################################
# Authentication configuration for cluster secrets store that can be one of api_key or trusted_profile
##############################################################################
variable "eso_authentication" {
  type        = string
  description = "Authentication method, Possible values are api_key or/and trusted_profile."
  default     = "trusted_profile"
  validation {
    condition     = contains(["api_key", "trusted_profile"], var.eso_authentication)
    error_message = "Authentication mode allowed are api_key or/and trusted_profile."
  }
  validation {
    condition     = var.eso_authentication == "trusted_profile" ? var.clusterstore_trusted_profile_name != null : true
    error_message = "Trusted profile authentication is enabled, therefore clusterstore_trusted_profile_name must be provided."
  }
}

variable "clusterstore_secret_name" {
  description = "Secret name to be used/referenced in the ESO cluster secrets store to pull from Secrets Manager"
  default     = "ibm-secret"
  type        = string
}

variable "clusterstore_secret_apikey" {
  type        = string
  description = "APIkey to be configured in the clusterstore_secret_name secret in the ESO cluster secrets store. One between clusterstore_secret_apikey and clusterstore_trusted_profile_name must be filled"
  sensitive   = true
  default     = null
  validation {
    condition     = var.eso_authentication == "api_key" ? var.clusterstore_secret_apikey != null : true
    error_message = "API Key authentication is enabled and scope for store is cluster, therefore clusterstore_secret_apikey must be provided."
  }
  validation {
    condition     = var.clusterstore_secret_apikey != null || var.clusterstore_trusted_profile_name != null
    error_message = "One of the variables clusterstore_secret_apikey and clusterstore_trusted_profile_name must be provided, cannot be both set to null"
  }
}

####### trusted profile

variable "clusterstore_trusted_profile_name" {
  type        = string
  description = "The name of the trusted profile to use for cluster secrets store scope. This allows ESO to use CRI based authentication to access secrets manager. The trusted profile must be created in advance"
  default     = null
}

####### Secrets Manager instance

variable "clusterstore_secrets_manager_guid" {
  type        = string
  description = "Secrets manager instance GUID for cluster secrets store where secrets will be stored or fetched from"
}
