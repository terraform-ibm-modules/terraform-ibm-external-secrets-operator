##############################################################################
# Input Variables for module
##############################################################################

##############################################################################
# Common vars
##############################################################################
variable "region" {
  description = "Region where resources will be sourced / created"
  type        = string
}

variable "secrets_manager_guid" {
  type        = string
  description = "Secrets manager instance GUID where secrets will be stored or fetched from"
}

##############################################################################
# Service ID setup vars
##############################################################################
variable "cr_namespace_name" {
  type        = string
  description = "Container registry namespace name to be configured in IAM policy."
}

variable "resource_group_id" {
  type        = string
  description = "The resource group ID in which the container registry namespace exists (used in IAM policy configuration)."
}

variable "service_id_name" {
  type        = string
  default     = "sid:0.0.1:image-secret-pull:automated:simple-service:container-registry:"
  description = "Name to be used for ServiceID."
}

variable "service_id_description" {
  type        = string
  default     = "ServiceId used to access container registry"
  description = "Description to be used for ServiceID."
}

##############################################################################
# Service ID SM secret setup vars
##############################################################################
variable "service_id_secret_group_id" {
  type        = string
  description = "Secret Group ID of SM IAM secret where Service ID apikey will be stored. Leave default (null) to add in default secret-group."
  default     = null
}

variable "service_id_secret_name" {
  type        = string
  description = "Name of SM IAM secret (dynamic ServiceID API Key) to be created."
  default     = "image-pull-iam-secret" #tfsec:ignore:general-secrets-no-plaintext-exposure
}

variable "service_id_secret_description" {
  type        = string
  default     = "API Key associated with image pull serviceid" #tfsec:ignore:general-secrets-no-plaintext-exposure
  description = "Description to be used for ServiceID API Key."
}
