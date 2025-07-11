#######################################################################
# Generic
#######################################################################

variable "prefix" {
  description = "Prefix for name of all resource created by this example"
  type        = string
  default     = "eso-clusterfull-test"
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
