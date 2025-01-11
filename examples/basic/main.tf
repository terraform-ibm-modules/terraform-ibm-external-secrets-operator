##############################################################################
# Locals
##############################################################################

# locals {

#   # general
#   validate_sm_region_cnd = var.existing_sm_instance_guid != null && var.existing_sm_instance_region == null
#   validate_sm_region_msg = "existing_sm_instance_region must also be set when value given for existing_sm_instance_guid."
#   # tflint-ignore: terraform_unused_declarations
#   validate_sm_region_chk = regex(
#     "^${local.validate_sm_region_msg}$",
#     (!local.validate_sm_region_cnd
#       ? local.validate_sm_region_msg
#   : ""))

#   sm_guid = var.existing_sm_instance_guid == null ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid

#   # https://github.ibm.com/GoldenEye/issues/issues/5268 - deployment region will match to sm_region as workaround
#   sm_region           = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
#   sm_acct_id          = var.existing_sm_instance_guid == null ? module.iam_secrets_engine[0].acct_secret_group_id : module.secrets_manager_group_acct[0].secret_group_id
#   es_namespace_apikey = "es-operator" # pragma: allowlist secret
#   eso_namespace       = "apikeynspace1"
# }

##################################################################
# Resource Group
##################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.1.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##################################################################
# Create VPC, public gateway and subnets
##################################################################
locals {

  vpc_cidr_bases = {
    private = "192.168.0.0/20",
    transit = "192.168.16.0/20",
    edge    = "192.168.32.0/20"
  }

  subnet_prefix = flatten([
    for k, v in module.zone_subnet_addrs : [
      for zone, cidr in v.network_cidr_blocks : {
        cidr       = cidr
        label      = k
        zone       = zone
        zone_index = split("-", zone)[1]
      }
    ]
  ])
}

resource "null_resource" "subnet_mappings" {
  count = length(var.zones)

  triggers = {
    name     = "${var.region}-${var.zones[count.index]}"
    new_bits = 2
  }
}

module "zone_subnet_addrs" {
  source   = "git::https://github.com/hashicorp/terraform-cidr-subnets.git?ref=v1.0.0"
  for_each = var.cidr_bases

  base_cidr_block = each.value

  networks = null_resource.subnet_mappings[*].triggers
}



# cidr_blocks     = ["192.168.0.0/20", "192.168.16.0/20", "192.168.32.0/20"]

# ocp_worker_pools = [
#   {
#     subnet_prefix    = "private"
#     pool_name        = "default"
#     machine_type     = "bx2.4x16"
#     workers_per_zone = 1
#     labels           = { "dedicated" : "private" }
#     operating_system = "REDHAT_8_64"
#   },
#   {
#     subnet_prefix    = "edge"
#     pool_name        = "edge"
#     machine_type     = "bx2.4x16"
#     workers_per_zone = 1
#     labels           = { "dedicated" : "edge" }
#     operating_system = "REDHAT_8_64"
#   },
#   {
#     subnet_prefix    = "transit"
#     pool_name        = "transit"
#     machine_type     = "bx2.4x16"
#     workers_per_zone = 1
#     labels           = { "dedicated" : "transit" }
#     operating_system = "REDHAT_8_64"
#   }
# ]


module "vpc" {
  source                      = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git?ref=v1.5.0"
  vpc_name                    = "${var.prefix}-vpc"
  resource_group_id           = module.resource_group.resource_group_id
  locations                   = []
  vpc_tags                    = var.resource_tags
  subnet_name_prefix          = "${var.prefix}-subnet"
  default_network_acl_name    = "${var.prefix}-nacl"
  default_routing_table_name  = "${var.prefix}-routing-table"
  default_security_group_name = "${var.prefix}-sg"
  create_gateway              = true
  public_gateway_name_prefix  = "${var.prefix}-pw"
  number_of_addresses         = 16
  auto_assign_address_prefix  = false
}

module "subnet_prefix" {
  source   = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/vpc-address-prefix"
  count    = length(local.subnet_prefix)
  name     = "${var.prefix}-z-${local.subnet_prefix[count.index].label}-${split("-", local.subnet_prefix[count.index].zone)[2]}"
  location = local.subnet_prefix[count.index].zone
  vpc_id   = module.vpc.vpc.vpc_id
  ip_range = local.subnet_prefix[count.index].cidr
}


module "subnets" {
  depends_on     = [module.subnet_prefix]
  source         = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/subnet"
  count          = length(local.subnet_prefix)
  location       = local.subnet_prefix[count.index].zone
  vpc_id         = module.vpc.vpc.vpc_id
  ip_range       = local.subnet_prefix[count.index].cidr
  name           = "${var.prefix}-subnet-${local.subnet_prefix[count.index].label}-${split("-", local.subnet_prefix[count.index].zone)[2]}"
  public_gateway = local.subnet_prefix[count.index].label == "edge" ? module.public_gateways[split("-", local.subnet_prefix[count.index].zone)[2] - 1].public_gateway_id : null
}

module "public_gateways" {
  source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/public-gateway"
  count             = length(var.zones)
  vpc_id            = module.vpc.vpc.vpc_id
  location          = "${var.region}-${var.zones[count.index]}"
  name              = "${var.prefix}-vpc-gateway-${var.zones[count.index]}"
  resource_group_id = module.resource_group.resource_group_id
  tags              = var.tags
}

# module "security_group" {
#   source                = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/security-group?ref=update_submodules"
#   create_security_group = true
#   name                  = "${var.prefix}-vpc-sg"
#   vpc_id                = module.vpc.vpc.vpc_id
#   resource_group_id     = module.resource_group.resource_group_id
#   security_group_rules = [
#     {
#       name      = "allow_all_inbound"
#       remote    = "0.0.0.0/0"
#       direction = "inbound"
#     }
#   ]
# }

# module "network_acl" {
#   source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/network-acl?ref=update_submodules"
#   name              = "${var.prefix}-vpc-acl"
#   vpc_id            = module.vpc.vpc.vpc_id
#   resource_group_id = module.resource_group.resource_group_id
#   rules = [
#     {
#       name        = "iks-create-worker-nodes-inbound"
#       action      = "allow"
#       source      = "161.26.0.0/16"
#       destination = "0.0.0.0/0"
#       direction   = "inbound"
#     },
#     {
#       name        = "iks-nodes-to-master-inbound"
#       action      = "allow"
#       source      = "166.8.0.0/14"
#       destination = "0.0.0.0/0"
#       direction   = "inbound"
#     },
#     {
#       name        = "iks-create-worker-nodes-outbound"
#       action      = "allow"
#       source      = "0.0.0.0/0"
#       destination = "161.26.0.0/16"
#       direction   = "outbound"
#     },
#     {
#       name        = "iks-worker-to-master-outbound"
#       action      = "allow"
#       source      = "0.0.0.0/0"
#       destination = "166.8.0.0/14"
#       direction   = "outbound"
#     },
#     {
#       name        = "allow-all-https-inbound"
#       source      = "0.0.0.0/0"
#       action      = "allow"
#       destination = "0.0.0.0/0"
#       direction   = "inbound"
#       tcp = {
#         source_port_min = 443
#         source_port_max = 443
#         port_min        = 1
#         port_max        = 65535
#       }
#     },
#     {
#       name        = "allow-all-https-outbound"
#       source      = "0.0.0.0/0"
#       action      = "allow"
#       destination = "0.0.0.0/0"
#       direction   = "outbound"
#       tcp = {
#         source_port_min = 1
#         source_port_max = 65535
#         port_min        = 443
#         port_max        = 443
#       }
#     },
#     {
#       name        = "deny-all-outbound"
#       action      = "deny"
#       source      = "0.0.0.0/0"
#       destination = "0.0.0.0/0"
#       direction   = "outbound"
#     },
#     {
#       name        = "deny-all-inbound"
#       action      = "deny"
#       source      = "0.0.0.0/0"
#       destination = "0.0.0.0/0"
#       direction   = "inbound"
#     }
#   ]
#   tags = var.tags
# }
# OCP CLUSTER creation
# module "ocp_base" {
#   source               = "terraform-ibm-modules/base-ocp-vpc/ibm"
#   version              = "3.34.0"
#   cluster_name         = "${var.prefix}-vpc"
#   resource_group_id    = module.resource_group.resource_group_id
#   region               = var.region
#   force_delete_storage = true
#   vpc_id               = module.vpc.vpc.vpc_id
#   vpc_subnets          = local.cluster_vpc_subnets
#   worker_pools         = local.ocp_worker_pools
#   tags                 = []
#   use_existing_cos     = false
#   # outbound required by cluster proxy
#   disable_outbound_traffic_protection = true
# }

# ##############################################################################
# # Init cluster config for helm and kubernetes providers
# ##############################################################################

# data "ibm_container_cluster_config" "cluster_config" {
#   cluster_name_id   = module.ocp_base.cluster_id
#   resource_group_id = module.resource_group.resource_group_id
# }

# # Wait time to allow cluster refreshes components after provisioning
# resource "time_sleep" "wait_45_seconds" {
#   depends_on      = [data.ibm_container_cluster_config.cluster_config]
#   create_duration = "45s"
# }

# # Create namespace for apikey auth
# resource "kubernetes_namespace" "apikey_namespace" {

#   metadata {
#     name = local.es_namespace_apikey
#   }
#   lifecycle {
#     ignore_changes = [
#       metadata[0].annotations,
#       metadata[0].labels
#     ]
#   }
#   depends_on = [
#     time_sleep.wait_45_seconds
#   ]
# }

# ########################################
# # Secrets-Manager and IAM configuration
# ########################################

# # IAM user policy, Secret Manager instance, Service ID for IAM engine, IAM service ID policies, associated Service ID API key stored in a secret object in account level secret-group and IAM engine configuration
# resource "ibm_resource_instance" "secrets_manager" {
#   count             = var.existing_sm_instance_guid == null ? 1 : 0
#   name              = "${var.prefix}-sm"
#   service           = "secrets-manager"
#   plan              = var.sm_service_plan
#   location          = local.sm_region
#   tags              = var.resource_tags
#   resource_group_id = module.resource_group.resource_group_id
#   timeouts {
#     create = "30m" # Extending provisioning time to 30 minutes
#   }
#   provider = ibm.ibm-sm
# }

# # Additional Secrets-Manager Secret-Group for SERVICE level secrets
# module "secrets_manager_group_acct" {
#   source               = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
#   version              = "1.2.2"
#   count                = var.existing_sm_instance_guid == null ? 0 : 1
#   region               = local.sm_region
#   secrets_manager_guid = local.sm_guid
#   #tfsec:ignore:general-secrets-no-plaintext-exposure
#   secret_group_name        = "${var.prefix}-account-secret-group"           #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
#   secret_group_description = "Secret-Group for storing account credentials" #tfsec:ignore:general-secrets-no-plaintext-exposure
#   depends_on               = [module.iam_secrets_engine]
#   providers = {
#     ibm = ibm.ibm-sm
#   }
# }

# # Configure instance with IAM engine
# module "iam_secrets_engine" {
#   count                                   = var.existing_sm_instance_guid == null ? 1 : 0
#   source                                  = "terraform-ibm-modules/secrets-manager-iam-engine/ibm"
#   version                                 = "1.2.6"
#   region                                  = local.sm_region
#   secrets_manager_guid                    = ibm_resource_instance.secrets_manager[0].guid
#   iam_secret_generator_service_id_name    = "${var.prefix}-sid:0.0.1:${ibm_resource_instance.secrets_manager[0].name}-iam-secret-generator:automated:simple-service:secret-manager:"
#   iam_secret_generator_apikey_name        = "${var.prefix}-iam-secret-generator-apikey"
#   new_secret_group_name                   = "${var.prefix}-account-secret-group"
#   iam_secret_generator_apikey_secret_name = "${var.prefix}-iam-secret-generator-apikey-secret"
#   iam_engine_name                         = "iam-engine"
#   providers = {
#     ibm = ibm.ibm-sm
#   }
# }

# ##################################################################
# # Create service-id, policy to pull secrets from secret manager
# ##################################################################

# # Create service-id
# resource "ibm_iam_service_id" "secret_puller" {
#   name        = "sid:0.0.1:${var.prefix}-secret-puller:automated:simple-service:secret-manager:"
#   description = "ServiceID that can pull secrets from Secret Manager"
# }

# # Create policy to allow new service id to pull secrets from secrets manager
# resource "ibm_iam_service_policy" "secret_puller_policy" {
#   iam_service_id = ibm_iam_service_id.secret_puller.id
#   roles          = ["Viewer", "SecretsReader"]

#   resources {
#     service              = "secrets-manager"
#     resource_instance_id = local.sm_guid
#     resource_type        = "secret-group"
#     resource             = local.sm_acct_id
#   }
# }

# ##################################################################
# # ESO deployment
# ##################################################################

# module "external_secrets_operator" {
#   source        = "../../"
#   eso_namespace = local.eso_namespace

#   eso_cluster_nodes_configuration = {
#     nodeSelector = {
#       label = "dedicated"
#       value = "edge"
#     }
#     tolerations = {
#       key      = "dedicated"
#       operator = "Equal"
#       value    = "edge"
#       effect   = "NoExecute"
#     }
#   }

#   depends_on = [
#     kubernetes_namespace.apikey_namespace
#   ]
# }
# #
# ## Create dynamic Service ID API key and add to secret manager
# module "dynamic_serviceid_apikey1" {
#   source  = "terraform-ibm-modules/iam-serviceid-apikey-secrets-manager/ibm"
#   version = "1.1.1"
#   region  = local.sm_region
#   #tfsec:ignore:general-secrets-no-plaintext-exposure
#   sm_iam_secret_name        = "${var.prefix}-${var.sm_iam_secret_name}"
#   sm_iam_secret_description = "Example of dynamic IAM secret / apikey" #tfsec:ignore:general-secrets-no-plaintext-exposure
#   serviceid_id              = ibm_iam_service_id.secret_puller.id
#   secrets_manager_guid      = local.sm_guid
#   secret_group_id           = local.sm_acct_id
#   depends_on                = [module.iam_secrets_engine, ibm_iam_service_policy.secret_puller_policy, ibm_iam_service_id.secret_puller]
#   providers = {
#     ibm = ibm.ibm-sm
#   }
# }

# ## Data source to get API Key from secret manager secret-puller-secret
# data "ibm_sm_iam_credentials_secret" "secret_puller_secret" {
#   instance_id = local.sm_guid
#   #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static type
#   secret_id = module.dynamic_serviceid_apikey1.secret_id
#   provider  = ibm.ibm-sm
# }

# ##################################################################
# # ESO ClusterStore creation with apikey authentication
# ##################################################################
# module "eso_clusterstore" {
#   source                            = "../../modules/eso-clusterstore"
#   eso_authentication                = "api_key"
#   clusterstore_secret_apikey        = data.ibm_sm_iam_credentials_secret.secret_puller_secret.api_key
#   region                            = local.sm_region
#   clusterstore_helm_rls_name        = "cluster-store"
#   clusterstore_secret_name          = "generic-cluster-api-key" #checkov:skip=CKV_SECRET_6
#   clusterstore_name                 = "cluster-store"
#   clusterstore_secrets_manager_guid = local.sm_guid
#   eso_namespace                     = local.eso_namespace
#   service_endpoints                 = "public"
#   depends_on = [
#     module.external_secrets_operator,
#   ]
# }

# ##################################################################
# # creation of generic username/password secret
# # (for example to store artifactory username and API key)
# ##################################################################

# locals {
#   # secret value for sm_userpass_secret
#   userpass_apikey = sensitive("password-payload-example")
# }

# # Create username_password secret and store in secret manager
# module "sm_userpass_secret" {
#   source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
#   version              = "1.4.0"
#   region               = local.sm_region
#   secrets_manager_guid = local.sm_guid
#   secret_group_id      = local.sm_acct_id
#   #tfsec:ignore:general-secrets-no-plaintext-exposure
#   secret_name             = "${var.prefix}-usernamepassword-secret"              # checkov:skip=CKV_SECRET_6
#   secret_description      = "example secret in existing secret manager instance" #tfsec:ignore:general-secrets-no-plaintext-exposure # checkov:skip=CKV_SECRET_6
#   secret_payload_password = local.userpass_apikey
#   secret_type             = "username_password" #checkov:skip=CKV_SECRET_6
#   #tfsec:ignore:general-secrets-no-plaintext-exposure
#   secret_username               = "artifactory-user" # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
#   secret_auto_rotation          = false
#   secret_auto_rotation_interval = 0
#   secret_auto_rotation_unit     = null
#   providers = {
#     ibm = ibm.ibm-sm
#   }
# }

# ##################################################################
# # ESO externalsecrets with cluster scope and apikey authentication
# ##################################################################

# # ESO externalsecret with cluster scope creating a dockerconfigjson type secret
# module "external_secret_usr_pass" {
#   depends_on                = [module.external_secrets_operator]
#   source                    = "../../modules/eso-external-secret"
#   es_kubernetes_secret_type = "dockerconfigjson"  #checkov:skip=CKV_SECRET_6
#   sm_secret_type            = "username_password" #checkov:skip=CKV_SECRET_6
#   sm_secret_id              = module.sm_userpass_secret.secret_id
#   es_kubernetes_namespace   = kubernetes_namespace.apikey_namespace.metadata[0].name
#   eso_store_name            = "cluster-store"
#   es_container_registry     = "wcp-my-team-docker-local.artifactory.swg-devops.com"
#   es_kubernetes_secret_name = "dockerconfigjson-uc" #checkov:skip=CKV_SECRET_6
#   es_helm_rls_name          = "es-docker-uc"
#   reloader_watching         = true
# }
