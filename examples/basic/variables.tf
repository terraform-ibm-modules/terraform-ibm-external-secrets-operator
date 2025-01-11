#######################################################################
# Generic
#######################################################################

variable "prefix" {
  description = "Prefix for name of all resource created by this example"
  type        = string
  default     = "eso-example-basic"
}

variable "region" {
  type        = string
  description = "Region where resources will be created."
  default     = "us-south"
}

variable "ibmcloud_api_key" {
  type        = string
  description = "APIkey that's associated with the account to use, set via environment variable TF_VAR_ibmcloud_api_key or .tfvars file."
  sensitive   = true
}

variable "resource_group" {
  type        = string
  description = "An existing resource group name to use for this example, if unset a new resource group will be created"
  default     = null
}

# tflint-ignore: terraform_unused_declarations
variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = []
}

## Image-pull module
variable "sm_iam_secret_name" {
  type        = string
  description = "Name of SM IAM secret (dynamic ServiceID API Key) to be created"
  default     = "sm-iam-secret-puller" #tfsec:ignore:general-secrets-no-plaintext-exposure
}

variable "sm_service_plan" {
  type        = string
  description = "Secrets-Manager trial plan"
  default     = "trial"
}

## ESO Module
variable "existing_sm_instance_guid" {
  type        = string
  description = "Existing Secrets Manager GUID. If not provided a new instance will be provisioned"
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Existing Secrets Manager Region. Required if value is passed into var.existing_instance_guid."
  default     = null
}

variable "tags" {
  description = "List of Tags for the ACL"
  type        = list(string)
  default     = null
}

variable "zones" {
  description = "List of zones"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "cidr_bases" {
  description = "A list of base CIDR blocks for each network zone"
  type        = map(string)
  default = {
    private = "192.168.0.0/20",
    transit = "192.168.16.0/20",
    edge    = "192.168.32.0/20"
  }
}

variable "new_bits" {
  description = "Number of additional address bits to use for numbering the new networks"
  type        = number
  default     = 2
}
