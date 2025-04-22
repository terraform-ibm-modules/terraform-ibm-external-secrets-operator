variable "eso_store_scope" {
  description = "Set to 'cluster' to configure ESO store as with cluster scope (ClusterSecretStore) or 'namespace' for regular namespaced scope (SecretStore). This value is used to configure the externalsecret reference"
  type        = string
  default     = "cluster"

  validation {
    condition     = var.eso_store_scope == "cluster" || var.eso_store_scope == "namespace"
    error_message = "The eso_store_deployment value must be one of the following: cluster, namespace"
  }
}

variable "es_kubernetes_namespace" {
  description = "Namespace to use to generate the externalsecret"
  type        = string
}

variable "es_kubernetes_secret_name" {
  description = "Name of the secret to use for the kubernetes secret object"
  type        = string
}

variable "es_refresh_interval" {
  description = "Specify interval for es secret synchronization. See recommendations for specifying/customizing refresh interval in this IBM Cloud article > https://cloud.ibm.com/docs/secrets-manager?topic=secrets-manager-tutorial-kubernetes-secrets#kubernetes-secrets-best-practices"
  default     = "1h"
  type        = string
  validation {
    condition     = can(regex("^[1-9][0-9]?[smh]$", var.es_refresh_interval))
    error_message = "The refresh interval must be a value between 1 and 99s(seconds)/m(minutes)/h(hours)."
  }
}
variable "eso_store_name" {
  description = "ESO store name to use when creating the externalsecret. Cannot be null and it is mandatory"
  type        = string
}

variable "es_kubernetes_secret_type" {
  description = "Secret type/format to be installed in the Kubernetes/Openshift cluster by ESO. Valid inputs are `opaque` `dockerconfigjson` and `tls`"
  type        = string
  validation {
    condition = can(regex("^opaque$|^dockerconfigjson$|^tls$|^$", var.es_kubernetes_secret_type))
    #  If it is empty, no secret will be created.
    error_message = "The es_kubernetes_secret_type value must be one of the following: opaque, dockerconfigjson, tls or leave it empty."
  }
  validation {
    condition     = (local.is_kv && var.es_kubernetes_secret_type != "opaque") ? false : true
    error_message = "For key-value secrets-manager secrets types es_kubernetes_secret_type cannot be different than opaque - found ${var.es_kubernetes_secret_type}"
  }
  validation {
    condition     = var.es_kubernetes_secret_data_key == null && (var.es_kubernetes_secret_type == "opaque" && (var.sm_secret_type == "arbitrary" || var.sm_secret_type == "iam_credentials")) ? false : true # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
    error_message = "A value for 'es_kubernetes_secret_data_key' must be passed when 'es_kubernetes_secret_type = opaque' and 'sm_secret_type' is either 'arbitrary' or 'iam_credentials'"
  }
  validation {
    condition     = (local.is_dockerjsonconfig_chain == true && (var.es_kubernetes_secret_type != "dockerconfigjson" || var.sm_secret_type != "iam_credentials")) ? false : true
    error_message = "If the externalsecret is expected to generate a dockerjsonconfig secrets chain the only supported value for es_kubernetes_secret_type is dockerconfigjson and for sm_secret_type is iam_credentials"
  }
}

variable "es_kubernetes_secret_data_key" {
  description = "Data key to be used in Kubernetes Opaque secret. Only needed when 'es_kubernetes_secret_type' is configured as `opaque` and sm_secret_type is set to either 'arbitrary' or 'iam_credentials'"
  type        = string
  default     = null
}

variable "sm_secret_type" {
  description = "Secrets-manager secret type to be used as source data by ESO. Valid input types are 'arbitrary', 'username_password' and 'iam_credentials'"
  type        = string
  validation {
    condition = can(regex("^iam_credentials$|^username_password$|^arbitrary$|^imported_cert$|^public_cert$|^private_cert|^kv$|$^$", var.sm_secret_type))
    # If it is empty, no secret will be created
    error_message = "The sm_secret_type value must be one of the following: iam_credentials, username_password, arbitrary, imported_cert, public_cert, private_cert, kv or leave it empty."
  }
  validation {
    condition     = (can(regex("^kv$", var.sm_secret_type)) && var.sm_kv_keyid != null && var.sm_kv_keypath != null) ? false : true
    error_message = "For key-value secrets only one of input variables 'sm_kv_keyid' or 'sm_kv_keypath' can be set."
  }
}

variable "sm_secret_id" {
  description = "Secrets-Manager secret ID where source data will be synchronized with Kubernetes secret. It can be null only in the case of a dockerjsonconfig secrets chain"
  type        = string
  validation {
    condition     = (var.sm_secret_id == null && local.is_dockerjsonconfig_chain == false) ? false : true
    error_message = "The input variable sm_secret_id can be null only a dockerjsonconfig secrets chain is going to be created"
  }
}

variable "es_container_registry" {
  type        = string
  default     = "us.icr.io"
  description = "The registry URL to be used in dockerconfigjson"
}

variable "es_container_registry_email" {
  type        = string
  description = "Optional - Email to be used in dockerconfigjson"
  default     = null
}

variable "es_container_registry_secrets_chain" {
  description = "Structure to generate a chain of secrets into a single dockerjsonconfig secret for multiple registries authentication."
  type = list(object({
    es_container_registry       = string
    sm_secret_id                = string # id of the secret storing the apikey that will be used for the secrets chain
    es_container_registry_email = optional(string, null)
  }))
  default  = []
  nullable = false
}

variable "es_helm_rls_name" {
  description = "Name to use for the helm release for externalsecrets resource. Must be unique in the namespace"
  type        = string
  validation {
    condition     = can(regex("^[0-9A-Za-z-]+$", var.es_helm_rls_name))
    error_message = "The value of the helm release for the es resource must match ^[0-9A-Za-z-]+$ regexp"
  }
}

variable "es_helm_rls_namespace" {
  description = "Namespace to deploy the helm release for the externalsecret. Default if null is the externalsecret namespace"
  type        = string
  validation {
    condition     = var.es_helm_rls_namespace == null || can(regex("^[0-9A-Za-z-]+$", var.es_helm_rls_namespace))
    error_message = "The value of the helm release for the es resource must match ^[0-9A-Za-z-]+$ regexp"
  }
  default = null
}

variable "sm_kv_keyid" {
  description = "Secrets-Manager key value (kv) keyid"
  type        = string
  default     = null
}

variable "sm_kv_keypath" {
  description = "Secrets-Manager key value (kv) keypath"
  type        = string
  default     = null
}

variable "sm_certificate_has_intermediate" {
  description = "The secret manager certificate is provided with intermediate certificate. By enabling this flag the certificate body on kube will contain certificate and intermediate content, otherwise only certificate will be added. Valid only for public and imported certificate"
  type        = bool
  default     = true
}

variable "reloader_watching" {
  description = "Flag to enable/disable the reloader watching. If enabled the reloader will watch for changes in the secret and reload the associated annotated pods if needed"
  type        = bool
  default     = false
}

# provider is affected by https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4803
# check for its status before switching to false
variable "sm_certificate_bundle" {
  description = "Flag to enable if the public/intermediate certificate is bundled. If enabled public key is managed as bundled with intermediate and private key, otherwise the template considers the public key not bundled with intermediate certificate and private key"
  type        = bool
  default     = true
}
