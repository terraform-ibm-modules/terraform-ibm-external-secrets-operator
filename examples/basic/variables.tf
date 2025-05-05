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
  validation {
    condition     = var.existing_sm_instance_guid != null ? var.existing_sm_instance_region != null : true
    error_message = "existing_sm_instance_region must also be set when value given for existing_sm_instance_guid."
  }
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Existing Secrets Manager Region. Required if value is passed into var.existing_instance_guid."
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
    default = "192.168.32.0/20"
  }
}

variable "acl_rules_list" {
  description = "List of rules that are to be attached to the Network ACL"
  type = list(object({
    name        = string
    action      = string
    source      = string
    destination = string
    direction   = string
    icmp = optional(object({
      code = number
      type = number
    }))
    tcp = optional(object({
      port_max        = number
      port_min        = number
      source_port_max = number
      source_port_min = number
    }))
    udp = optional(object({
      port_max        = number
      port_min        = number
      source_port_max = number
      source_port_min = number
    }))
  }))
  default = [
    {
      name        = "iks-create-worker-nodes-inbound"
      action      = "allow"
      source      = "161.26.0.0/16"
      destination = "0.0.0.0/0"
      direction   = "inbound"
    },
    {
      name        = "iks-nodes-to-master-inbound"
      action      = "allow"
      source      = "166.8.0.0/14"
      destination = "0.0.0.0/0"
      direction   = "inbound"
    },
    {
      name        = "iks-create-worker-nodes-outbound"
      action      = "allow"
      source      = "0.0.0.0/0"
      destination = "161.26.0.0/16"
      direction   = "outbound"
    },
    {
      name        = "iks-worker-to-master-outbound"
      action      = "allow"
      source      = "0.0.0.0/0"
      destination = "166.8.0.0/14"
      direction   = "outbound"
    },
    {
      name        = "allow-all-https-inbound"
      source      = "0.0.0.0/0"
      action      = "allow"
      destination = "0.0.0.0/0"
      direction   = "inbound"
      tcp = {
        source_port_min = 443
        source_port_max = 443
        port_min        = 1
        port_max        = 65535
      }
    },
    {
      name        = "allow-all-https-outbound"
      source      = "0.0.0.0/0"
      action      = "allow"
      destination = "0.0.0.0/0"
      direction   = "outbound"
      tcp = {
        source_port_min = 1
        source_port_max = 65535
        port_min        = 443
        port_max        = 443
      }
    },
    {
      name        = "deny-all-outbound"
      action      = "deny"
      source      = "0.0.0.0/0"
      destination = "0.0.0.0/0"
      direction   = "outbound"
    },
    {
      name        = "deny-all-inbound"
      action      = "deny"
      source      = "0.0.0.0/0"
      destination = "0.0.0.0/0"
      direction   = "inbound"
    }
  ]
}
