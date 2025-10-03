############################################################################################################
# EXTERNAL SECRETS CONFIGURATIONS
############################################################################################################

variable "eso_namespace" {
  description = "Namespace to create and be used to install ESO components including helm releases."
  type        = string
  default     = null
}

variable "existing_eso_namespace" {
  description = "Existing Namespace to be used to install ESO components including helm releases."
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

# external secrets image and helm charts references

variable "eso_image" {
  type        = string
  description = "The External Secrets Operator image in the format of `[registry-url]/[namespace]/[image]`."
  default     = "ghcr.io/external-secrets/external-secrets"
  nullable    = false
}

variable "eso_image_version" {
  type        = string
  description = "The version or digest for the external secrets image to deploy. If changing the value, ensure it is compatible with the chart version set in eso_chart_version."
  default     = "v0.20.2-ubi@sha256:cbe2c6af3a24f1b9b9465986616a9976ab6d23513bbaed94ae6d1c8187067df9" # datasource: ghcr.io/external-secrets/external-secrets
  nullable    = false
  validation {
    condition     = can(regex("(^v\\d+\\.\\d+.\\d+(\\-\\w+)?(\\@sha256\\:\\w+){0,1})$", var.eso_image_version))
    error_message = "The value of the external secrets image version must match classic version or the tag and sha256 image digest format"
  }
}

variable "eso_chart_location" {
  type        = string
  description = "The location of the External Secrets Operator Helm chart."
  default     = "https://charts.external-secrets.io"
  nullable    = false
}

variable "eso_chart_version" {
  type        = string
  description = "The version of the External Secrets Operator Helm chart. Ensure that the chart version is compatible with the image version specified in eso_image_version."
  default     = "0.20.2" # registryUrl: charts.external-secrets.io
  nullable    = false
}

############################################################################################################
# RELOADER CONFIGURATIONS
############################################################################################################

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

# reloader image and helm charts references

variable "reloader_image" {
  type        = string
  description = "The reloader image repository in the format of `[registry-url]/[namespace]/[image]`."
  default     = "ghcr.io/stakater/reloader"
  nullable    = false

}

variable "reloader_image_version" {
  type        = string
  description = "The version or digest for the reloader image to deploy. If changing the value, ensure it is compatible with the chart version set in reloader_chart_version."
  default     = "v1.4.8-ubi@sha256:d87801fae5424f347d34b776ba25ea0c1ba80a8b50ba91ece0777206a47d91d3" # datasource: ghcr.io/stakater/reloader
  nullable    = false
  validation {
    condition     = can(regex("(^v\\d+\\.\\d+.\\d+(\\-\\w+)?(\\@sha256\\:\\w+){0,1})$", var.reloader_image_version))
    error_message = "The value of the reloader image version must match classic version or the tag and sha256 image digest format"
  }
}

variable "reloader_chart_location" {
  type        = string
  description = "The location of the Reloader Helm chart."
  default     = "https://stakater.github.io/stakater-charts"
  nullable    = false
}

variable "reloader_chart_version" {
  type        = string
  description = "The version of the Reloader Helm chart. Ensure that the chart version is compatible with the image version specified in reloader_image_version."
  default     = "2.2.3" # registryUrl: stakater.github.io/stakater-charts
  nullable    = false
}
