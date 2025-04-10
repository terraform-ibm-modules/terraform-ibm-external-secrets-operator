######## eso generic configurations

variable "region" {
  description = "Region where Secrets Manager is deployed. It will be used to build the regional URL to the service"
  type        = string
}

variable "sstore_helm_rls_name" {
  description = "Name of helm release for external secret"
  type        = string
  default     = "external-secret-store"
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
  validation {
    condition     = var.eso_authentication == "api_key" ? var.sstore_secret_apikey != null : true
    error_message = "API Key authentication is enabled and scope for store is cluster, therefore sstore_secret_apikey must be provided."
  }
  validation {
    condition     = var.eso_authentication == "trusted_profile" ? var.sstore_trusted_profile_name != null : true
    error_message = "Trusted profile authentication is enabled, therefore sstore_trusted_profile_name must be provided."
  }
}

####### apikey authentication

variable "sstore_secret_name" {
  description = "Secret name to be used/referenced in the ESO secretstore to pull from Secrets Manager"
  default     = "ibm-secret"
  type        = string
}

variable "sstore_secret_apikey" {
  description = "APIkey to be stored into sstore_secret_name to authenticate on Secrets Manager instance"
  type        = string
  default     = null
  validation {
    condition     = var.sstore_secret_apikey != null || var.sstore_trusted_profile_name != null
    error_message = "One of the variables sstore_secret_apikey and sstore_trusted_profile_name must be provided, cannot be both set to null"
  }
}

####### trusted profile

variable "sstore_trusted_profile_name" {
  type        = string
  description = "The name of the trusted profile to use for the secretstore. This allows ESO to use CRI based authentication to access secrets manager. The trusted profile must be created in advance"
  default     = null
}

variable "sstore_secrets_manager_guid" {
  type        = string
  description = "Secrets manager instance GUID for secretstore where secrets will be stored or fetched from"
}

variable "sstore_namespace" {
  type        = string
  description = "Namespace to create the SecretStore. The namespace must exist as it is not created by this module"
}

variable "sstore_store_name" {
  type        = string
  description = "Name of the SecretStore to create"
}
