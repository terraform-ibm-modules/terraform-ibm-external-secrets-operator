locals {
  prefix = var.prefix != null ? (var.prefix != "" ? var.prefix : null) : null
}

# parsing cluster crn to collect the cluster ID and the region it is deployed into
module "crn_parser_cluster" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.4.1"
  crn     = var.existing_cluster_crn
}

# parsing secrets manager crn to collect the secrets manager ID and its region
module "crn_parser_sm" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.4.1"
  crn     = var.existing_secrets_manager_crn
}

locals {
  cluster_id          = module.crn_parser_cluster.service_instance
  cluster_region      = module.crn_parser_cluster.region
  sm_region           = module.crn_parser_sm.region
  sm_guid             = module.crn_parser_sm.service_instance
  sm_ibmcloud_api_key = var.secrets_manager_ibmcloud_api_key == null ? var.ibmcloud_api_key : var.secrets_manager_ibmcloud_api_key
}

data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id = local.cluster_id
}

##################################################################
# ESO deployment configuration
# Configures ESO and reloader deployments
##################################################################

locals {
  # converting list of strings to comma separated values as expected by the module
  reloader_namespaces_to_ignore    = length(var.reloader_namespaces_to_ignore) != 0 ? join(", ", var.reloader_namespaces_to_ignore) : null
  reloader_resources_to_ignore     = length(var.reloader_resources_to_ignore) != 0 ? join(", ", var.reloader_resources_to_ignore) : null
  reloader_namespaces_selector     = length(var.reloader_namespaces_selector) != 0 ? join(", ", var.reloader_namespaces_selector) : null
  reloader_resource_label_selector = length(var.reloader_resource_label_selector) != 0 ? join(", ", var.reloader_resource_label_selector) : null
}

module "external_secrets_operator" {
  source                    = "../../"
  eso_namespace             = var.eso_namespace
  existing_eso_namespace    = var.existing_eso_namespace
  eso_enroll_in_servicemesh = var.eso_enroll_in_servicemesh
  # ESO configuration
  eso_cluster_nodes_configuration = var.eso_cluster_nodes_configuration
  eso_pod_configuration           = var.eso_pod_configuration
  eso_image                       = var.eso_image
  eso_image_version               = var.eso_image_version
  eso_chart_location              = var.eso_chart_location
  eso_chart_version               = var.eso_chart_version
  # reloader configuration
  reloader_deployed                = var.reloader_deployed
  reloader_reload_strategy         = var.reloader_reload_strategy
  reloader_namespaces_to_ignore    = local.reloader_namespaces_to_ignore
  reloader_resources_to_ignore     = local.reloader_resources_to_ignore
  reloader_namespaces_selector     = local.reloader_namespaces_selector
  reloader_resource_label_selector = local.reloader_resource_label_selector
  reloader_ignore_secrets          = var.reloader_ignore_secrets
  reloader_ignore_configmaps       = var.reloader_ignore_configmaps
  reloader_is_openshift            = var.reloader_is_openshift
  reloader_is_argo_rollouts        = var.reloader_is_argo_rollouts
  reloader_reload_on_create        = var.reloader_reload_on_create
  reloader_sync_after_restart      = var.reloader_sync_after_restart
  reloader_pod_monitor_metrics     = var.reloader_pod_monitor_metrics
  reloader_log_format              = var.reloader_log_format
  reloader_custom_values           = var.reloader_custom_values
  reloader_image                   = var.reloader_image
  reloader_image_version           = var.reloader_image_version
  reloader_chart_location          = var.reloader_chart_location
  reloader_chart_version           = var.reloader_chart_version
}

##################################################################
# ESO Cluster secrets stores management
##################################################################

# for each element of cluster_secrets_stores going to create
# 1. service secrets groups (the secrets groups to contain the secrets read by the ESO) to create if any
# 2. account secrets group (the secrets group to store the secrets used by the ESO to connect to the secrets manager and pull the secrets values) to create if any
# 3. the trusted profile to create if any
# 4. the service id to read the secrets from the secrets manager if any

locals {

  # list of service secrets groups to create for each cluster secrets store - each element of the map has a key with the name of the clustersecretsstore concatenated to the secrets group name (using "." as separator) to keep the keys unique
  # flatten ensures that this local value is a flat list of objects, rather than a list of lists of objects
  cluster_secrets_stores_service_secrets_groups_list = flatten([
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores : [
      for service_secrets_group_key, service_secrets_group in cluster_secrets_store.service_secrets_groups_list : {
        key         = "${cluster_secrets_store_key}.${service_secrets_group.name}"
        name        = try("${local.prefix}-${service_secrets_group.name}", service_secrets_group.name)
        description = service_secrets_group.description
      }
    ]
  ])

}

# service secrets groups for the cluster secrets stores
module "cluster_secrets_stores_service_secrets_groups" {
  for_each = tomap({
    for idx, element in local.cluster_secrets_stores_service_secrets_groups_list : element.key => element
  })
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.4.2"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = each.value.name        # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = each.value.description #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

locals {
  # map of cluster secrets stores service secrets groups enriched with the created secrets groups details
  cluster_secrets_stores_service_secrets_groups = {
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => [
      for service_secrets_group_key, service_secrets_group in cluster_secrets_store.service_secrets_groups_list : {
        key           = "${cluster_secrets_store_key}.${service_secrets_group.name}"
        name          = try("${local.prefix}-${service_secrets_group.name}", service_secrets_group.name)
        description   = service_secrets_group.description
        secrets_group = module.cluster_secrets_stores_service_secrets_groups["${cluster_secrets_store_key}.${service_secrets_group.name}"]
      }
    ]
  }
}

# trusted profile authentication for the cluster secrets stores
locals {
  # putting together the service secrets groups IDs to use for each cluster secrets store with the trusted profile to read them
  cluster_secrets_stores_trusted_profile_to_create = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "trusted_profile_name" : try("${local.prefix}-${cluster_secrets_store.trusted_profile_name}", cluster_secrets_store.trusted_profile_name)
      "trusted_profile_description" : cluster_secrets_store.trusted_profile_description != null ? cluster_secrets_store.trusted_profile_description : "Trusted profile for the secrets store ${cluster_secrets_store_key}"
      "trusted_profile_service_secrets_groups_IDs" : local.cluster_secrets_stores_service_secrets_groups_fulllist[cluster_secrets_store_key]
    } if(cluster_secrets_store.trusted_profile_name != null && cluster_secrets_store.trusted_profile_name != "")
  })
}

# creating trusted profiles for the secrets groups created with module tp_clusterstore_secrets_manager_group
module "cluster_secrets_store_trusted_profile" {
  for_each                        = local.cluster_secrets_stores_trusted_profile_to_create
  source                          = "../../modules/eso-trusted-profile"
  trusted_profile_name            = each.value.trusted_profile_name
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = each.value.trusted_profile_service_secrets_groups_IDs
  tp_cluster_crn                  = var.existing_cluster_crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}

# account secrets groups for the cluster secrets stores
module "cluster_secrets_stores_account_secrets_groups" {
  for_each = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "name" : try("${local.prefix}-${cluster_secrets_store.account_secrets_group_name}", cluster_secrets_store.account_secrets_group_name)
      "description" : cluster_secrets_store.account_secrets_group_description
    } if(cluster_secrets_store.existing_account_secrets_group_id == null || cluster_secrets_store.existing_account_secrets_group_id == "") && cluster_secrets_store.account_secrets_group_name != null
  })
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.4.2"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = each.value.name        # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = each.value.description #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}
#data lookup for iam id
data "ibm_iam_service_id" "existing_serviceid" {
  for_each = {
    for k, v in var.eso_secretsstores_configuration.cluster_secrets_stores :
    k => v
    if v.existing_serviceid_id != null && v.existing_serviceid_id != ""
  }

  name = each.value.serviceid_name

}

#data lookup for iam id
data "ibm_iam_service_id" "existing_serviceid_secrets" {
  for_each = {
    for k, v in var.eso_secretsstores_configuration.secrets_stores :
    k => v
    if v.existing_serviceid_id != null && v.existing_serviceid_id != ""
  }

  name = each.value.serviceid_name

}

locals {
  # map of cluster secrets stores account secrets groups enriched with the created secrets groups details
  cluster_secrets_stores_account_secrets_groups = {
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      name          = try("${local.prefix}-${cluster_secrets_store.account_secrets_group_name}", cluster_secrets_store.account_secrets_group_name)
      secrets_group = module.cluster_secrets_stores_account_secrets_groups[cluster_secrets_store_key]

    }
  }
}

# for each cluster secrets store creating the service id to pull secrets if existing service id is not provided
resource "ibm_iam_service_id" "cluster_secrets_stores_secret_puller" {
  for_each = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "name" : try("${local.prefix}-${cluster_secrets_store.serviceid_name}", cluster_secrets_store.serviceid_name)
      "description" : cluster_secrets_store.serviceid_description
    } if(cluster_secrets_store.existing_serviceid_id == null || cluster_secrets_store.existing_serviceid_id == "")
  })
  name        = each.value.name
  description = each.value.description
}

locals {
  # map of serviceIDs details owning the secrets to pull from Secrets Manager for each cluster secrets stores
  cluster_secrets_stores_secret_puller_service_ids = {
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "name" : try("${local.prefix}-${cluster_secrets_store.serviceid_name}", cluster_secrets_store.serviceid_name)
      "service_id" : ibm_iam_service_id.cluster_secrets_stores_secret_puller[cluster_secrets_store_key]
    } if(cluster_secrets_store.existing_serviceid_id == null || cluster_secrets_store.existing_serviceid_id == "")
  }
}

# cluster secrets stores namespaces creation
module "cluster_secrets_store_namespace" {
  for_each = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "namespace" : cluster_secrets_store.namespace
    } if cluster_secrets_store.create_namespace == true
  })
  source  = "terraform-ibm-modules/namespace/ibm"
  version = "2.0.0"
  namespaces = [
    {
      name = each.value.namespace
      metadata = {
        name        = each.value.namespace
        labels      = {}
        annotations = {}
      }
    }
  ]
}

locals {
  # generating the list of service secrets groups ids to use with the cluster secrets store authentication configuration

  # putting together the service secrets groups IDs to use for each cluster secrets store
  cluster_secrets_stores_service_secrets_groups_fulllist = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => concat(
      cluster_secrets_store.existing_service_secrets_group_id_list,
      [for service_secrets_group_key, service_secrets_group in cluster_secrets_store.service_secrets_groups_list : module.cluster_secrets_stores_service_secrets_groups["${cluster_secrets_store_key}.${service_secrets_group.name}"].secret_group_id]
    )
  })

  # putting together the service secrets groups IDs to use for each cluster secrets store with the account secrets group ID to read them
  cluster_secrets_stores_policies_to_create = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      # if the existing_serviceid_id is null it collects the service id created otherwise will use the existing one
      "accountServiceID" : (cluster_secrets_store.existing_serviceid_id == null || cluster_secrets_store.existing_serviceid_id == "") ? ibm_iam_service_id.cluster_secrets_stores_secret_puller[cluster_secrets_store_key].iam_id : data.ibm_iam_service_id.existing_serviceid[cluster_secrets_store_key].iam_id
      "service_secrets_groups_IDs" : local.cluster_secrets_stores_service_secrets_groups_fulllist[cluster_secrets_store_key]
    }
  })

  # temporary step to create a final map to process to create the policies from the account secrets group ID to each of the service secrets groups IDs
  cluster_secrets_stores_policies_to_create_temp = flatten([
    for cluster_secrets_store_key, cluster_store_element in local.cluster_secrets_stores_policies_to_create : [
      for index, service_secrets_group_id in cluster_store_element.service_secrets_groups_IDs : {
        # creating the key value as the combination of the cluster secrets store key and the service secrets group ID to avoid duplicates in the next map
        cluster_secrets_store_key = cluster_secrets_store_key # keeping this key needed during cluster secrets store creation
        key                       = "${cluster_secrets_store_key}.csg${index}"
        accountServiceID          = cluster_store_element.accountServiceID
        service_secrets_group_ID  = service_secrets_group_id
      }
    ]
  ])

  # final flat map to process to create the policies using for_each, using as key of the map the combination of the cluster secrets store key and the service secrets group ID to avoid duplicates in the map
  cluster_secrets_stores_policies_to_create_map = tomap({
    for idx, element in local.cluster_secrets_stores_policies_to_create_temp : element.key => element
  })
}

# Create policy to allow new service id to pull secrets from secrets manager
resource "ibm_iam_service_policy" "cluster_secrets_store_secrets_puller_policy" {
  for_each = local.cluster_secrets_stores_policies_to_create_map
  iam_id   = each.value.accountServiceID
  roles    = ["Viewer", "SecretsReader"]
  resources {
    service              = "secrets-manager"
    resource_instance_id = local.sm_guid
    resource_type        = "secret-group"
    resource             = each.value.service_secrets_group_ID
  }
}

# create for each Service ID the relative API key and add it to secret manager
module "cluster_secrets_store_account_serviceid_apikey" {
  for_each = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "accountServiceID" : (cluster_secrets_store.existing_serviceid_id == null || cluster_secrets_store.existing_serviceid_id == "") ? ibm_iam_service_id.cluster_secrets_stores_secret_puller[cluster_secrets_store_key].id : cluster_secrets_store.existing_serviceid_id
      "secretGroupID" : cluster_secrets_store.existing_account_secrets_group_id != null && cluster_secrets_store.existing_account_secrets_group_id != "" ? cluster_secrets_store.existing_account_secrets_group_id : module.cluster_secrets_stores_account_secrets_groups[cluster_secrets_store_key].secret_group_id
    }
  })
  source  = "terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm"
  version = "1.2.20"
  region  = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_iam_secret_name        = try("${local.prefix}-${each.key}-${each.value.accountServiceID}-apikey", "${each.key}-${each.value.accountServiceID}-apikey")
  sm_iam_secret_description = "API key for serviceID ${each.value.accountServiceID}" #tfsec:ignore:general-secrets-no-plaintext-exposure
  serviceid_id              = each.value.accountServiceID
  secrets_manager_guid      = local.sm_guid
  secret_group_id           = each.value.secretGroupID
  providers = {
    ibm = ibm.ibm-sm
  }
}

# data source to get the API key to pull secrets from secrets manager
data "ibm_sm_iam_credentials_secret" "cluster_secrets_store_account_serviceid_apikey" {
  # for_each = local.cluster_secrets_stores_policies_to_create_map
  for_each    = var.eso_secretsstores_configuration.cluster_secrets_stores
  instance_id = local.sm_guid
  #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static type
  secret_id = module.cluster_secrets_store_account_serviceid_apikey[each.key].secret_id
  provider  = ibm.ibm-sm
}

locals {
  # map of account ServiceIDs enriched with the created secrets manager secret details
  cluster_secrets_store_account_serviceid_apikey_secrets = {
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "account_service_id" : (cluster_secrets_store.existing_serviceid_id == null || cluster_secrets_store.existing_serviceid_id == "") ? ibm_iam_service_id.cluster_secrets_stores_secret_puller[cluster_secrets_store_key].id : cluster_secrets_store.existing_serviceid_id
      "secrets_group_id" : cluster_secrets_store.existing_account_secrets_group_id != null && cluster_secrets_store.existing_account_secrets_group_id != "" ? cluster_secrets_store.existing_account_secrets_group_id : module.cluster_secrets_stores_account_secrets_groups[cluster_secrets_store_key].secret_group_id
      "secrets_manager_secret" : module.cluster_secrets_store_account_serviceid_apikey[cluster_secrets_store_key]
    }
  }
}

##################################################################
# ESO Secrets stores management
##################################################################

# for each element of secrets_stores going to create
# 1. service secrets groups (the secrets groups to contain the secrets read by the ESO) to create if any
# 2. account secrets group (the secrets group to store the secrets used by the ESO to connect to the secrets manager and pull the secrets values) to create if any
# 3. the trusted profile to create if any
# 4. the service id to read the secrets from the secrets manager if any

locals {
  # list of service secrets groups to create for each secrets store - each element of the map has a key with the name of the secretsstore concatenated to the secrets group name (using "." as separator) to keep the keys unique
  # flatten ensures that this local value is a flat list of objects, rather than a list of lists of objects

  secrets_stores_service_secrets_groups_list = flatten([
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores : [
      for service_secrets_group_key, service_secrets_group in secrets_store.service_secrets_groups_list : {
        key         = "${secrets_store_key}.${service_secrets_group.name}"
        name        = try("${local.prefix}-${service_secrets_group.name}", service_secrets_group.name)
        description = service_secrets_group.description
      }
    ]
  ])

}

# service secrets groups for the secrets stores
module "secrets_stores_service_secrets_groups" {
  for_each = tomap({
    for idx, element in local.secrets_stores_service_secrets_groups_list : element.key => element
  })
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.4.2"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = each.value.name        # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = each.value.description #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

locals {
  # map of service secrets groups details for each secrets store
  secrets_stores_service_secrets_groups = {
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => [
      for service_secrets_group_key, service_secrets_group in secrets_store.service_secrets_groups_list : {
        key           = "${secrets_store_key}.${service_secrets_group.name}"
        name          = try("${local.prefix}-${service_secrets_group.name}", service_secrets_group.name)
        description   = service_secrets_group.description
        secrets_group = module.secrets_stores_service_secrets_groups["${secrets_store_key}.${service_secrets_group.name}"]
      }
    ]
  }
}

# trusted profile authentication for secrets stores
locals {
  # putting together the service secrets groups IDs to use for each secrets store with the trusted profile to read them
  secrets_stores_trusted_profile_to_create = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "trusted_profile_name" : try("${local.prefix}-${secrets_store.trusted_profile_name}", secrets_store.trusted_profile_name)
      "trusted_profile_description" : secrets_store.trusted_profile_description != null ? secrets_store.trusted_profile_description : "Trusted profile for the secrets store ${secrets_store_key}"
      "trusted_profile_service_secrets_groups_IDs" : local.secrets_stores_service_secrets_groups_fulllist[secrets_store_key]
    } if(secrets_store.trusted_profile_name != null && secrets_store.trusted_profile_name != "")
  })
}

# creating trusted profiles for the secrets groups created with module tp_secrets_manager_groups
module "secrets_stores_trusted_profiles" {
  for_each                        = local.secrets_stores_trusted_profile_to_create
  source                          = "../../modules/eso-trusted-profile"
  trusted_profile_name            = each.value.trusted_profile_name
  secrets_manager_guid            = local.sm_guid
  secret_groups_id                = each.value.trusted_profile_service_secrets_groups_IDs
  tp_cluster_crn                  = var.existing_cluster_crn
  trusted_profile_claim_rule_type = "ROKS_SA"
  tp_namespace                    = var.eso_namespace
}

# account secrets group for the secrets stores
module "secrets_stores_account_secrets_groups" {
  for_each = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "name" : try("${local.prefix}-${secrets_store.account_secrets_group_name}", secrets_store.account_secrets_group_name)
      "description" : secrets_store.account_secrets_group_description
    } if(secrets_store.existing_account_secrets_group_id == null || secrets_store.existing_account_secrets_group_id == "") && secrets_store.account_secrets_group_name != null
  })
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.4.2"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = each.value.name        # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = each.value.description #tfsec:ignore:general-secrets-no-plaintext-exposure
  providers = {
    ibm = ibm.ibm-sm
  }
}

locals {

  # map of account secrets groups details for each secrets stores
  secrets_stores_account_secrets_groups = {
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      name          = try("${local.prefix}-${secrets_store.account_secrets_group_name}", secrets_store.account_secrets_group_name)
      secrets_group = module.secrets_stores_account_secrets_groups[secrets_store_key]
    }
  }
}

# for each secrets store creating the service id to pull secrets if existing service id is not provided
resource "ibm_iam_service_id" "secrets_stores_secret_puller" {
  for_each = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "name" : try("${local.prefix}-${secrets_store.serviceid_name}", secrets_store.serviceid_name)
      "description" : secrets_store.serviceid_description
    } if(secrets_store.existing_serviceid_id == null || secrets_store.existing_serviceid_id == "")
  })
  name        = each.value.name
  description = each.value.description
}

locals {
  # map of serviceID details for pulling secrets from Secrets Manager for each secrets stores
  secrets_stores_secret_puller_service_ids = {
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "name" : try("${local.prefix}-${secrets_store.serviceid_name}", secrets_store.serviceid_name)
      "service_id" : ibm_iam_service_id.secrets_stores_secret_puller[secrets_store_key]
    } if(secrets_store.existing_serviceid_id == null || secrets_store.existing_serviceid_id == "")
  }
}

# cluster secrets stores namespaces creation
module "secrets_store_namespace" {
  for_each = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "namespace" : secrets_store.namespace
    } if secrets_store.create_namespace == true
  })
  source  = "terraform-ibm-modules/namespace/ibm"
  version = "2.0.0"
  namespaces = [
    {
      name = each.value.namespace
      metadata = {
        name        = each.value.namespace
        labels      = {}
        annotations = {}
      }
    }
  ]
}

locals {
  # generating the list of service secrets groups ids to use with the secrets store authentication configuration

  # putting together the service secrets groups IDs to use for each secrets store
  secrets_stores_service_secrets_groups_fulllist = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => concat(
      secrets_store.existing_service_secrets_group_id_list,
      [for service_secrets_group_key, service_secrets_group in secrets_store.service_secrets_groups_list : module.secrets_stores_service_secrets_groups["${secrets_store_key}.${service_secrets_group.name}"].secret_group_id]
    )
  })

  # putting together the service secrets groups IDs to use for each secrets store with the account secrets group ID to read them
  secrets_stores_policies_to_create = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      # if the existing_serviceid_id is null it collects the service id created otherwise will use the existing one
      "accountServiceID" : (secrets_store.existing_serviceid_id == null || secrets_store.existing_serviceid_id == "") ? ibm_iam_service_id.secrets_stores_secret_puller[secrets_store_key].iam_id : data.ibm_iam_service_id.existing_serviceid_secrets[secrets_store_key].iam_id
      "service_secrets_groups_IDs" : local.secrets_stores_service_secrets_groups_fulllist[secrets_store_key]
    }
  })

  # temporary step to create a final map to process to create the policies from the account secrets group ID to each of the service secrets groups IDs
  secrets_stores_policies_to_create_temp = flatten([
    for secrets_store_key, store_element in local.secrets_stores_policies_to_create : [
      for index, service_secrets_group_id in store_element.service_secrets_groups_IDs : {
        # creating the key value as the combination of the secrets store key and the service secrets group ID to avoid duplicates in the next map
        secrets_store_key        = secrets_store_key # keeping this key needed during secrets store creation
        key                      = "${secrets_store_key}.ssg${index}"
        accountServiceID         = store_element.accountServiceID
        service_secrets_group_ID = service_secrets_group_id
      }
    ]
  ])

  # final flat map to process to create the policies using for_each, using as key of the map the combination of the secrets store key and the service secrets group ID to avoid duplicates in the map
  secrets_stores_policies_to_create_map = tomap({
    for idx, element in local.secrets_stores_policies_to_create_temp : element.key => element
  })
}

# Create policy to allow new service id to pull secrets from secrets manager
resource "ibm_iam_service_policy" "secrets_store_secrets_puller_policy" {
  for_each = local.secrets_stores_policies_to_create_map
  iam_id   = each.value.accountServiceID
  roles    = ["Viewer", "SecretsReader"]
  resources {
    service              = "secrets-manager"
    resource_instance_id = local.sm_guid
    resource_type        = "secret-group"
    resource             = each.value.service_secrets_group_ID
  }
}

# create for each Service ID the relative API key and add it to secret manager
module "secrets_store_account_serviceid_apikey" {
  for_each = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "accountServiceID" : (secrets_store.existing_serviceid_id == null || secrets_store.existing_serviceid_id == "") ? ibm_iam_service_id.secrets_stores_secret_puller[secrets_store_key].id : secrets_store.existing_serviceid_id
      "secretGroupID" : secrets_store.existing_account_secrets_group_id != null && secrets_store.existing_account_secrets_group_id != "" ? secrets_store.existing_account_secrets_group_id : module.secrets_stores_account_secrets_groups[secrets_store_key].secret_group_id
    }
  })
  source  = "terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm"
  version = "1.2.20"
  region  = local.sm_region
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  sm_iam_secret_name        = try("${local.prefix}-${each.key}-${each.value.accountServiceID}-apikey", "${each.key}-${each.value.accountServiceID}-apikey")
  sm_iam_secret_description = "API key for serviceID ${each.value.accountServiceID}" #tfsec:ignore:general-secrets-no-plaintext-exposure
  serviceid_id              = each.value.accountServiceID
  secrets_manager_guid      = local.sm_guid
  secret_group_id           = each.value.secretGroupID
  providers = {
    ibm = ibm.ibm-sm
  }
}

locals {
  # map of Secrets Manager secrets details for pulling secrets from Secrets Manager for each secrets stores
  secrets_store_account_serviceid_apikey_secrets = {
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "account_service_id" : (secrets_store.existing_serviceid_id == null || secrets_store.existing_serviceid_id == null) ? ibm_iam_service_id.secrets_stores_secret_puller[secrets_store_key].id : secrets_store.existing_serviceid_id
      "secrets_group_id" : secrets_store.existing_account_secrets_group_id != null && secrets_store.existing_account_secrets_group_id != "" ? secrets_store.existing_account_secrets_group_id : module.secrets_stores_account_secrets_groups[secrets_store_key].secret_group_id
      "secrets_manager_secret" : module.secrets_store_account_serviceid_apikey[secrets_store_key]
    }
  }
}

# # data source to get the API key to pull secrets from secrets manager
data "ibm_sm_iam_credentials_secret" "secrets_store_account_serviceid_apikey" {
  for_each    = var.eso_secretsstores_configuration.secrets_stores
  instance_id = local.sm_guid
  #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static type
  secret_id = module.secrets_store_account_serviceid_apikey[each.key].secret_id
  provider  = ibm.ibm-sm
}

# creation of the ESO ClusterStore (cluster wide scope)

module "eso_clustersecretsstore" {
  for_each = tomap({
    for cluster_secrets_store_key, cluster_secrets_store in var.eso_secretsstores_configuration.cluster_secrets_stores :
    cluster_secrets_store_key => {
      "name" : cluster_secrets_store_key
      "authentication" : cluster_secrets_store.trusted_profile_name != null && cluster_secrets_store.trusted_profile_name != "" ? "trusted_profile" : "api_key"
      "secret_apikey" : data.ibm_sm_iam_credentials_secret.cluster_secrets_store_account_serviceid_apikey[cluster_secrets_store_key].api_key != null ? data.ibm_sm_iam_credentials_secret.cluster_secrets_store_account_serviceid_apikey[cluster_secrets_store_key].api_key : null
      "trusted_profile_name" : cluster_secrets_store.trusted_profile_name != null && cluster_secrets_store.trusted_profile_name != "" ? try("${local.prefix}-${cluster_secrets_store.trusted_profile_name}", cluster_secrets_store.trusted_profile_name) : null
      "namespace" : cluster_secrets_store.namespace
    }
  })
  source                            = "../../modules/eso-clusterstore"
  eso_authentication                = each.value.authentication
  clusterstore_secret_apikey        = each.value.secret_apikey
  region                            = local.sm_region
  clusterstore_helm_rls_name        = "${each.value.name}-helmrelease"
  clusterstore_secret_name          = each.value.secret_apikey != null ? "${each.value.name}-auth-apikey" : null #checkov:skip=CKV_SECRET_6
  clusterstore_name                 = each.value.name
  clusterstore_secrets_manager_guid = local.sm_guid
  eso_namespace                     = each.value.namespace
  service_endpoints                 = var.service_endpoints
  clusterstore_trusted_profile_name = each.value.trusted_profile_name != null && each.value.trusted_profile_name != "" ? each.value.trusted_profile_name : null
  depends_on = [
    module.external_secrets_operator, module.cluster_secrets_store_namespace
  ]
}

# creation of namespace scoped secrets store
module "eso_secretsstore" {
  for_each = tomap({
    for secrets_store_key, secrets_store in var.eso_secretsstores_configuration.secrets_stores :
    secrets_store_key => {
      "name" : secrets_store_key
      "authentication" : secrets_store.trusted_profile_name != null && secrets_store.trusted_profile_name != "" ? "trusted_profile" : "api_key"
      "secret_apikey" : data.ibm_sm_iam_credentials_secret.secrets_store_account_serviceid_apikey[secrets_store_key].api_key != null ? data.ibm_sm_iam_credentials_secret.secrets_store_account_serviceid_apikey[secrets_store_key].api_key : null
      "trusted_profile_name" : secrets_store.trusted_profile_name != null && secrets_store.trusted_profile_name != "" ? try("${local.prefix}-${secrets_store.trusted_profile_name}", secrets_store.trusted_profile_name) : null
      "namespace" : secrets_store.namespace
    }
  })
  depends_on                  = [module.external_secrets_operator, module.secrets_store_namespace]
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = each.value.authentication
  region                      = local.sm_region
  sstore_namespace            = each.value.namespace
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = each.value.name
  sstore_secret_apikey        = each.value.secret_apikey
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "${each.value.name}-helmrelease"
  sstore_trusted_profile_name = each.value.trusted_profile_name != null && each.value.trusted_profile_name != "" ? each.value.trusted_profile_name : null
  sstore_secret_name          = each.value.secret_apikey != null ? "${each.value.name}-auth-apikey" : null #checkov:skip=CKV_SECRET_6
}
