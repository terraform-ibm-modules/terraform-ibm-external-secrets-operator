#######################################################################
# Generic
#######################################################################

variable "prefix" {
  description = "Prefix for name of all resource created by this example"
  type        = string
  default     = "eso-example"
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

variable "cr_namespace_name" {
  type        = string
  description = "Container registry namespace name to be configured in IAM policy."
  default     = "cr-namespace"
}

## ESO Module

variable "eso_namespace" {
  type        = string
  description = "Namespace to deploy the External secrets Operator into"
  default     = "es-operator"
}

variable "es_namespaces_apikey" {
  type        = list(string)
  description = "Namespace(s) where secrets and secretstore will be created for apikey auth"
  default     = ["apikeynspace1", "apikeynspace2", "apikeynspace3", "apikeynspace4"]
}

variable "es_namespaces_tp" {
  type        = list(string)
  description = "Namespace(s) for the secrets synched through trusted profile authentication."
  default     = ["tpnspace1", "tpnspace2"]
}

variable "es_namespace_tp_multi_sg" {
  type        = string
  description = "Namespace for the secrets synched through trusted profile authentication and TP policy with multiple secrets groups policy."
  default     = "tpns-multisg"
}

variable "es_namespace_tp_no_sg" {
  type        = string
  description = "Namespace for the secret synched through trusted profile authentication and TP policy without secrets groups."
  default     = "tpns-nosg"
}

variable "es_refresh_interval" {
  description = "Specify interval for es secret synchronization"
  default     = "1h"
  type        = string
}

variable "existing_sm_instance_guid" {
  type        = string
  description = "Existing Secrets Manager GUID. If not provided a new instance will be provisioned"
  default     = null
}

variable "existing_sm_instance_crn" {
  type        = string
  description = "Existing Secrets Manager CRN. If existing_sm_instance_guid is provided, also this input must be provided."
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Existing Secrets Manager Region. Required if value is passed into var.existing_instance_guid."
  default     = null
}

variable "service_endpoints" {
  type        = string
  description = "The service endpoint type to communicate with the provided secrets manager instance. Possible values are `public` or `private`. This also will set the iam endpoint for containerAuth when enabling Trusted Profile/CR based authentication."
  default     = "public"
}

## public certificate secret configuration
variable "skip_iam_authorization_policy" {
  type        = bool
  default     = false
  description = "To skip the CIS IAM policy creation. To set to true if already exists (i.e. if using an existing SM instance)"
}

variable "cert_common_name" {
  description = "Public certificate common name"
  type        = string
}

variable "ca_name" {
  type        = string
  description = "Secret Managers certificate authority name. If null it will be set to [prefix value]-project-ca"
  default     = null
}

variable "dns_provider_name" {
  type        = string
  description = "Secret Managers DNS provider name.  If null it will be set to [prefix value]-project-dns"
  default     = null
}

variable "public_certificate_bundle" {
  description = "Flag to enable the certificate bundle. If enabled the intermediate certificate is expected to be bundled with public, otherwise the template considers the intermediate field explicitly"
  type        = bool
  default     = true
}

variable "acme_letsencrypt_private_key_sm_id" {
  type        = string
  description = "Secrets Manager id where the Acme Lets Encrypt private key for certificate authority is stored"
  default     = null
}

variable "acme_letsencrypt_private_key_secret_id" {
  type        = string
  description = "Secret id for the Acme Lets Encrypt private key for certificate authority stored in Secrets Manager"
  default     = null
}

variable "acme_letsencrypt_private_key_sm_region" {
  type        = string
  description = "Region of the Secrets Manager id where the Acme Lets Encrypt private key for certificate authority is stored"
  default     = null
}

variable "acme_letsencrypt_private_key" {
  type        = string
  description = "Acme Lets Encrypt private key for certificate authority"
  default     = null
}

# imported certificate
variable "imported_certificate_sm_id" {
  type        = string
  default     = null
  description = "Secrets Manager instance id where the components for the intermediate certificate are stored"
}

variable "imported_certificate_sm_region" {
  type        = string
  default     = null
  description = "Region of the Secrets Manager instance where the components for the intermediate certificate are stored"
}

variable "imported_certificate_intermediate_secret_id" {
  type        = string
  default     = null
  description = "Secret id where the intermediate certificate for the imported certificate is stored"
}

variable "imported_certificate_public_secret_id" {
  type        = string
  default     = null
  description = "Secret id where the public certificate for the imported certificate is stored"
}

variable "imported_certificate_private_secret_id" {
  type        = string
  default     = null
  description = "Secret id where the private key for the imported certificate is stored"
}

variable "existing_cis_instance_name" {
  type        = string
  description = "Existing CIS instance name to create the dns configuration for the public certificate"
  nullable    = false
}

variable "existing_cis_instance_resource_group_id" {
  type        = string
  description = "Resource group ID of the existing CIS instance name to create the dns configuration for the public certificate"
  nullable    = false
}

### private certificate secret configuration
variable "pvt_cert_common_name" {
  description = "Private certificate common name"
  type        = string
}

variable "pvt_ca_name" {
  type        = string
  description = "Secret Managers certificate authority name. If null it will be set to pvt-[prefix]-project-root-ca"
  default     = null
}

variable "pvt_root_ca_common_name" {
  type        = string
  description = "Root CA common name for the private certificate"
}

variable "pvt_ca_max_ttl" {
  type        = string
  description = "Private certificate CA max TTL"
  default     = "8760h"
}

variable "pvt_certificate_template_name" {
  type        = string
  description = "Template name for the private certificate to create"
  default     = null
}
