variable "ibmcloud_api_key" {
  type        = string
  description = "APIkey that's associated with the account to use, set via environment variable TF_VAR_ibmcloud_api_key"
  sensitive   = true
}

variable "cluster_name_id" {
  type        = string
  description = "Cluster Name or ID where resources will be created"
}

variable "resource_group" {
  type        = string
  description = "An existing resource group name to use for this example, if unset a new resource group will be created"
  default     = null
}


variable "prefix" {
  description = "Prefix for name of all resource created by this example"
  type        = string
  default     = "eso-tp"
}

variable "service_endpoints" {
  type        = string
  description = "The service endpoint type to communicate with the provided secrets manager instance. Possible values are `public` or `private`. This also will set the iam endpoint for containerAuth when enabling Trusted Profile/CR based authentication."
  default     = "public"
}

variable "region" {
  type        = string
  description = "Region where resources will be created"
  default     = "us-south"
}

variable "existing_sm_instance_guid" {
  type        = string
  description = "Existing Secrets Manager GUID. If not provided a new instance will be provisioned"
  default     = null
  validation {
    condition     = var.existing_sm_instance_guid != null ? var.existing_sm_instance_region != null : true
    error_message = "existing_sm_instance_region must also be set when value given for existing_sm_instance_guid."
  }
  validation {
    condition     = var.existing_sm_instance_guid != null && var.service_endpoints == "private" ? var.existing_sm_instance_crn != null : true
    error_message = "existing_sm_instance_crn must also be set when value given for existing_sm_instance_guid if service_endpoints is private."
  }
}

variable "existing_sm_instance_crn" {
  type        = string
  description = "Existing Secrets Manager CRN. If existing_sm_instance_guid is provided, also this input must be provided."
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Existing Secrets Manager Region. Required if value is passed into var.existing_sm_instance_guid"
  default     = null
}

variable "eso_namespace" {
  type        = string
  description = "Namespace to deploy the External secrets Operator into"
  default     = "es-operator"
}

variable "vpe_vpc_name" {
  type        = string
  description = "Name of the VPC where to create the VPE endpoint in the case of private connections. Required only if service_endpoints is private"
  default     = null
}

variable "vpe_vpc_id" {
  type        = string
  description = "ID of the VPC where to create the VPE endpoint in the case of private connections. Required only if service_endpoints is private"
  default     = null
}

variable "vpe_vpc_subnets" {
  type        = list(string)
  description = "List of VPC subnets to use to create the VPE endpoints. Required only if service_endpoints is private"
  default     = []
}

variable "vpe_vpc_resource_group_id" {
  type        = string
  description = "ID of resource group to use to create the VPE endpoint in the case of private connections (the same of the VPC usually). Required only if service_endpoints is private"
  default     = null
}

variable "vpe_vpc_security_group_id" {
  type        = string
  description = "ID of security group to use to create the VPE endpoint in the case of private connections (one of the VPC). Required only if service_endpoints is private"
  default     = null
}

variable "eso_deployment_nodes_configuration" {
  type        = string
  description = "Configuration to deploy ESO on specific cluster nodes. The value of this variable will be used for NodeSelector label value and tolerations configuration. If null standard ESO deployment is done."
  default     = null
}
