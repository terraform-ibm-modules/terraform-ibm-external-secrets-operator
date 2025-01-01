variable "trusted_profile_name" {
  type        = string
  description = "The name of the trusted profile to be used. This allows ESO to use CRI based authentication to access secrets manager. The trusted profile must be created in advance"
}

variable "secrets_manager_guid" {
  type        = string
  description = "Secrets manager instance GUID where secrets will be stored or fetched from and the trusted profile will allow access to."
}

variable "secret_groups_id" {
  type        = list(string)
  description = "The list of secret groups to limit access to for the trusted profile to create."
  default     = []
}

variable "tp_cluster_crn" {
  type        = string
  description = "Target cluster CRN for the trusted profile. Used when creating trusted profile"
}

variable "trusted_profile_claim_rule_type" {
  description = "Trusted profile claim rule type, set the value to 'ROKS_SA' for ROKS clusters, set to ROKS for IKS clusters"
  type        = string
  default     = "ROKS_SA"
  validation {
    condition     = var.trusted_profile_claim_rule_type == "ROKS_SA" || var.trusted_profile_claim_rule_type == "ROKS"
    error_message = "The trusted_profile_claim_rule_type value must be one of the following: ROKS_SA, ROKS"
  }
}

variable "tp_namespace" {
  description = "Namespace to configure in the Trusted Profile on IAM. Its value must be the namespace where the operator is deployed and running."
  type        = string
}
