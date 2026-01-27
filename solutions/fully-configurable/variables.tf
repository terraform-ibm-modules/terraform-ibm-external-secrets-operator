#######################################################################
# Generic
#######################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "IBM Cloud API Key"
  sensitive   = true
}

variable "secrets_manager_ibmcloud_api_key" {
  type        = string
  description = "API key to authenticate on Secrets Manager instance. If null the ibmcloud_api_key will be used."
  default     = null
  sensitive   = true
}

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. Supported values are `public`, `private`, `public-and-private`. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.provider_visibility)
    error_message = "Invalid visibility option. Allowed values are 'public', 'private', or 'public-and-private'."
  }
}

variable "prefix" {
  type        = string
  nullable    = true
  description = "The prefix to add to all resources that this solution creates (e.g `prod`, `test`, `dev`). To skip using a prefix, set this value to null or an empty string. [Learn more](https://terraform-ibm-modules.github.io/documentation/#/prefix.md)."

  validation {
    # - null and empty string is allowed
    # - Must not contain consecutive hyphens (--): length(regexall("--", var.prefix)) == 0
    # - Starts with a lowercase letter: [a-z]
    # - Contains only lowercase letters (a–z), digits (0–9), and hyphens (-)
    # - Must not end with a hyphen (-): [a-z0-9]
    condition = (var.prefix == null || var.prefix == "" ? true :
      alltrue([
        can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.prefix)),
        length(regexall("--", var.prefix)) == 0
      ])
    )
    error_message = "Prefix must begin with a lowercase letter and may contain only lowercase letters, digits, and hyphens '-'. It must not end with a hyphen('-'), and cannot contain consecutive hyphens ('--')."
  }

  validation {
    # must not exceed 16 characters in length
    condition     = var.prefix == null || var.prefix == "" ? true : length(var.prefix) <= 16
    error_message = "Prefix must not exceed 16 characters."
  }
}

variable "existing_cluster_crn" {
  type        = string
  description = "The CRN of the to deploy ESO operator onto. This value cannot be null."
  nullable    = false

  validation {
    condition = anytrue([
      can(regex("^crn:v\\d:(.*:){2}containers-kubernetes:(.*:)([aos]\\/[\\w_\\-]+):[a-z0-9]{20}::$", var.existing_cluster_crn)),
      var.existing_cluster_crn == null,
    ])
    error_message = "The value provided for 'existing_cluster_crn' is not valid."
  }
}

variable "existing_secrets_manager_crn" {
  type        = string
  description = "The CRN of the existing Secrets Manager instance to use. This value cannot be null."
  nullable    = false

  validation {
    condition = anytrue([
      can(regex("^crn:v\\d:(.*:){2}secrets-manager:(.*:)([aos]\\/[\\w_\\-]+):[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}::$", var.existing_secrets_manager_crn)),
      var.existing_secrets_manager_crn == null,
    ])
    error_message = "The value provided for 'existing_secrets_manager_crn' is not valid."
  }
}

############################################################################################################
# ESO DEPLOYMENT CONFIGURATION
############################################################################################################

variable "eso_namespace" {
  type        = string
  description = "Cluster namespace to create and to deploy the External secrets Operator and Reloader into."
  default     = "es-operator"
  validation {
    condition     = var.eso_namespace == null || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.eso_namespace))
    error_message = "The value of the eso_namespace must be a valid Kubernetes namespace name"
  }
}

variable "existing_eso_namespace" {
  type        = string
  description = "Existing cluster namespace to deploy the External secrets Operator and Reloader into. If eso_namespace is not null, this value will be ignored."
  default     = null
  validation {
    condition     = var.existing_eso_namespace == null || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.existing_eso_namespace))
    error_message = "The value of the existing_eso_namespace must be a valid Kubernetes namespace name."
  }
  validation {
    condition     = var.existing_eso_namespace == null && var.eso_namespace == null ? false : true
    error_message = "The values of var.existing_eso_namespace and var.eso_namespace cannot be null at the same time."
  }
}

variable "eso_cluster_nodes_configuration" {
  description = "Configuration to use to customise ESO deployment on specific cluster nodes. Default value is null to keep ESO standard deployment. Learn more [here](https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator#customise-eso-deployment-on-specific-cluster-nodes)"
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
  description = "Configuration to use to customise ESO deployment on specific pods. Default value is {} to keep ESO standard deployment. Ignore if not needed."
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

# external secrets operator image and helm charts references
variable "eso_image" {
  type        = string
  description = "The External Secrets Operator image in the format of `[registry-url]/[namespace]/[image]`."
  default     = "ghcr.io/external-secrets/external-secrets"
  nullable    = false
}

variable "eso_image_version" {
  type        = string
  description = "The version or digest for the external secrets image to deploy. If changing the value, ensure it is compatible with the chart version set in eso_chart_version."
  default     = "v1.3.1-ubi@sha256:c78700629305811661a5d4954e92e746ee7acad57d53fb11a79e7add6557c8d3" # datasource: ghcr.io/external-secrets/external-secrets
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
  default     = "1.3.1" # registryUrl: charts.external-secrets.io
  nullable    = false
}

# ESO
variable "eso_enroll_in_servicemesh" {
  description = "Flag to enroll the External Secrets Operator into RedHat Service Mesh adding the istio-injection annotation to the ESO namespace and to ESO pods. Default to false."
  type        = bool
  default     = false
}

############################################################################################################
# RELOADER DEPLOYMENT CONFIGURATION
############################################################################################################

variable "reloader_deployed" {
  description = "Flag to enable the deployment of [reloader](https://github.com/stakater/Reloader) along with ESO. Learn more [here](https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator#pod-reloader)"
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
  type        = list(string)
  default     = []
}

variable "reloader_resources_to_ignore" {
  description = "List of comma separated resources to ignore for reloader. If multiple are provided they are combined with the AND operator"
  type        = list(string)
  default     = []
}

variable "reloader_namespaces_selector" {
  description = "List of comma separated label selectors, if multiple are provided they are combined with the AND operator"
  type        = list(string)
  default     = []
}

variable "reloader_resource_label_selector" {
  description = "List of comma separated label selectors, if multiple are provided they are combined with the AND operator"
  type        = list(string)
  default     = []
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
  description = "String containing custom values to be used for reloader helm chart. More details [here](https://github.com/stakater/Reloader/blob/master/deployments/kubernetes/chart/reloader/values.yaml)"
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
  default     = "v1.4.12-ubi@sha256:bfd348922b44630783b092de36de0afc0a87182d595e0c6d6b27997bc41e242e" # datasource: ghcr.io/stakater/reloader
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
  default     = "2.2.7" # registryUrl: stakater.github.io/stakater-charts
  nullable    = false
}

# secrets stores configuration

variable "eso_secretsstores_configuration" {
  description = "Configuration of the [cluster secrets stores](https://external-secrets.io/latest/api/clustersecretstore/) and [secrets stores](https://external-secrets.io/latest/api/secretstore/) to create. Learn more about this configuration [here](https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator/blob/main/solutions/fully-configurable/DA-eso-configuration.md)"
  type = object({
    cluster_secrets_stores = map(object({
      namespace                              = string
      create_namespace                       = bool
      existing_serviceid_id                  = optional(string, null)
      serviceid_name                         = optional(string, null)
      serviceid_description                  = optional(string, null)
      existing_account_secrets_group_id      = optional(string, null)
      account_secrets_group_name             = optional(string, null)
      account_secrets_group_description      = optional(string, null)
      trusted_profile_name                   = optional(string, null) # if both the trusted_profile_name and the serviceid_name/existing_serviceid_id are set, the trusted_profile_name will be used
      trusted_profile_description            = optional(string, null)
      existing_service_secrets_group_id_list = optional(list(string), [])
      service_secrets_groups_list = optional(list(object({
        name        = string
        description = string
      })), [])
    }))
    secrets_stores = map(object({
      create_namespace                       = bool
      namespace                              = optional(string, null)
      existing_serviceid_id                  = optional(string, null)
      serviceid_name                         = optional(string, null)
      serviceid_description                  = optional(string, null)
      existing_account_secrets_group_id      = optional(string, null)
      account_secrets_group_name             = optional(string, null)
      account_secrets_group_description      = optional(string, null)
      trusted_profile_name                   = optional(string, null) # if both the trusted_profile_name and the serviceid_name/existing_serviceid_id are set, the trusted_profile_name will be used
      trusted_profile_description            = optional(string, null)
      existing_service_secrets_group_id_list = optional(list(string), [])
      service_secrets_groups_list = optional(list(object({
        name        = string
        description = string
      })), [])
    }))
  })
  default = {
    cluster_secrets_stores = {}
    secrets_stores         = {}
  }
}

variable "service_endpoints" {
  type        = string
  description = "The service endpoint type to communicate with the provided secrets manager instance. Possible values are `public` or `private`. This also will set the iam endpoint for containerAuth when enabling Trusted Profile/CR based authentication."
  default     = "private"
}
