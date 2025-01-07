######## eso generic configurations

variable "eso_namespace" {
  description = "Namespace to create and be used to install ESO components including helm releases. If eso_store_scope == cluster, this will also be used to deploy ClusterSecretStore/cluster_store in it"
  type        = string
  default     = null
}

variable "existing_eso_namespace" {
  description = "Existing Namespace to be used to install ESO components including helm releases. If eso_store_scope == cluster, this will also be used to deploy ClusterSecretStore/cluster_store in it"
  type        = string
  default     = null
}

# ESO deployment cluster nodes configuration
variable "eso_cluster_nodes_configuration" {
  description = "Configuration to use to customise ESO deployment on specific cluster nodes. Setting appropriate values will result in customising ESO helm release. Default value is null to keep ESO standard deployment."
  type = object({
    nodeSelector = object({
      label = string
      value = string
    })
    tolerations = object({
      key      = string
      operator = string
      value    = string
      effect   = string
    })
  })
  default = null
}

# ESO deployment cluster pods configuration
variable "eso_pod_configuration" {
  description = "Configuration to use to customise ESO deployment on specific pods. Setting appropriate values will result in customising ESO helm release. Default value is {} to keep ESO standard deployment. Ignore the key if not required."
  type = object({
    annotations = optional(object({
      # The annotations for external secret controller pods.
      external_secrets = optional(map(string), {})
      # The annotations for external secret cert controller pods.
      external_secrets_cert_controller = optional(map(string), {})
      # The annotations for external secret controller pods.
      external_secrets_webhook = optional(map(string), {})
    }), {})

    labels = optional(object({
      # The labels for external secret controller pods.
      external_secrets = optional(map(string), {})
      # The labels for external secret cert controller pods.
      external_secrets_cert_controller = optional(map(string), {})
      # The labels for external secret controller pods.
      external_secrets_webhook = optional(map(string), {})
    }), {})
  })

  default = {}
}

# ESO
variable "eso_enroll_in_servicemesh" {
  description = "Flag to enroll ESO into istio servicemesh"
  type        = bool
  default     = false
}

# Reloader variables full documentation https://github.com/stakater/Reloader/tree/master#helm-charts
variable "reloader_deployed" {
  description = "Whether to deploy reloader or not https://github.com/stakater/Reloader"
  type        = bool
  default     = true
}
variable "reloader_reload_strategy" {
  description = "The reload strategy to use for reloader. Possible values are `env-vars` or `annotations`. Default value is `annotations`"
  type        = string
  default     = "annotations"
  validation {
    condition     = contains(["env-vars", "annotations"], var.reloader_reload_strategy)
    error_message = "The specified reloader_reload_strategy is not a valid selection! Valid values are `env-vars` or `annotations`"
  }
}
variable "reloader_namespaces_to_ignore" {
  description = "List of comma separated namespaces to ignore for reloader. If multiple are provided they are combined with the AND operator"
  type        = string
  default     = null
}
variable "reloader_resources_to_ignore" {
  description = "List of comma separated resources to ignore for reloader. If multiple are provided they are combined with the AND operator"
  type        = string
  default     = null
}
variable "reloader_namespaces_selector" {
  description = "List of comma separated label selectors, if multiple are provided they are combined with the AND operator"
  type        = string
  default     = null
}
variable "reloader_resource_label_selector" {
  description = "List of comma separated label selectors, if multiple are provided they are combined with the AND operator"
  type        = string
  default     = null
}
variable "reloader_ignore_secrets" {
  description = "Whether to ignore secret changes or not"
  type        = bool
  default     = false
}
variable "reloader_ignore_configmaps" {
  description = "Whether to ignore configmap changes or not"
  type        = bool
  default     = false
}
variable "reloader_is_openshift" {
  description = "Enable OpenShift DeploymentConfigs"
  type        = bool
  default     = true
}
variable "reloader_is_argo_rollouts" {
  description = "Enable Argo Rollouts"
  type        = bool
  default     = false
}
variable "reloader_reload_on_create" {
  description = "Enable reload on create events"
  type        = bool
  default     = true

}
variable "reloader_sync_after_restart" {
  description = "Enable sync after Reloader restarts for Add events, works only when reloadOnCreate is true"
  type        = bool
  default     = true

}
variable "reloader_pod_monitor_metrics" {
  description = "Enable to scrape Reloader's Prometheus metrics"
  type        = bool
  default     = false
}

variable "reloader_log_format" {
  description = "The log format to use for reloader. Possible values are `json` or `text`. Default value is `json`"
  type        = string
  default     = "text"
  validation {
    condition     = contains(["json", "text"], var.reloader_log_format)
    error_message = "The specified reloader_log_format is not a valid selection! Valid values are `json` or `text`"
  }
}
variable "reloader_custom_values" {
  description = "String containing custom values to be used for reloader helm chart. See https://github.com/stakater/Reloader/blob/master/deployments/kubernetes/chart/reloader/values.yaml"
  type        = string
  default     = null
}

variable "eso_image_repo" {
  type        = string
  description = "The repository for the External Secrets Operator image. Default is `ghcr.io/external-secrets/external-secrets`."
  default     = "ghcr.io/external-secrets/external-secrets"
}

variable "eso_image_tag_digest" {
  type        = string
  description = "The tag or digest for the External Secrets Operator image. Provide a digest in the format `sha256:xxxxx...` for immutability or leave it as a tag version."
  default     = "v0.11.0-ubi@sha256:b5f685b86cf684020e863c6c2ed91e8a79cad68260d7149ddee073ece2573d6f"
}
