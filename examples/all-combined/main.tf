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

  # sDNLB entitled account API key - if null the ibmcloud_api_key will be used
  sdnlb_ibmcloud_api_key = var.sdnlb_ibmcloud_api_key == null ? var.ibmcloud_api_key : var.sdnlb_ibmcloud_api_key

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


merged_subnets = [
  for subnet in module.subnets : 
    merge(
      subnet,
      {
        label      = lookup([for sk in local.subnet_prefix : sk if sk.cidr == subnet.subnet_ipv4_cidr][0], "label", "")
        zone       = lookup([for sk in local.subnet_prefix : sk if sk.cidr == subnet.subnet_ipv4_cidr][0], "zone", "")
      }
    )
]

subnets = {
  edge = [for subnet in local.merged_subnets : {id = subnet.subnet_id, cidr_block = subnet.subnet_ipv4_cidr, zone = subnet.zone} if subnet.label == "edge"],
  private = [for subnet in local.merged_subnets : {id = subnet.subnet_id, cidr_block = subnet.subnet_ipv4_cidr, zone = subnet.zone} if subnet.label == "private"],
  transit = [for subnet in local.merged_subnets : {id = subnet.subnet_id, cidr_block = subnet.subnet_ipv4_cidr, zone = subnet.zone} if subnet.label == "transit"]
}

  ocp_worker_pools = [
  {
    subnet_prefix    = "private"
    pool_name        = "default"
    machine_type     = "bx2.4x16"
    workers_per_zone = 1
    labels           = { "dedicated" : "private" }
    operating_system = "REDHAT_8_64"
  },
  {
    subnet_prefix    = "edge"
    pool_name        = "edge"
    machine_type     = "bx2.4x16"
    workers_per_zone = 1
    labels           = { "dedicated" : "edge" }
    operating_system = "REDHAT_8_64"
  },
  {
    subnet_prefix    = "transit"
    pool_name        = "transit"
    machine_type     = "bx2.4x16"
    workers_per_zone = 1
    labels           = { "dedicated" : "transit" }
    operating_system = "REDHAT_8_64"
  }
]

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
  source   = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/vpc-address-prefix?ref=v1.5.0"
  count    = length(local.subnet_prefix)
  name     = "${var.prefix}-z-${local.subnet_prefix[count.index].label}-${split("-", local.subnet_prefix[count.index].zone)[2]}"
  location = local.subnet_prefix[count.index].zone
  vpc_id   = module.vpc.vpc.vpc_id
  ip_range = local.subnet_prefix[count.index].cidr
}


module "subnets" {
  depends_on     = [module.subnet_prefix]
  source         = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/subnet?ref=v1.5.0"
  count          = length(local.subnet_prefix)
  location       = local.subnet_prefix[count.index].zone
  vpc_id         = module.vpc.vpc.vpc_id
  ip_range       = local.subnet_prefix[count.index].cidr
  name           = "${var.prefix}-subnet-${local.subnet_prefix[count.index].label}-${split("-", local.subnet_prefix[count.index].zone)[2]}"
  public_gateway = local.subnet_prefix[count.index].label == "edge" ? module.public_gateways[split("-", local.subnet_prefix[count.index].zone)[2] - 1].public_gateway_id : null
  subnet_access_control_list = module.network_acl.network_acl_id
}

module "public_gateways" {
  source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/public-gateway?ref=v1.5.0"
  count             = length(var.zones)
  vpc_id            = module.vpc.vpc.vpc_id
  location          = "${var.region}-${var.zones[count.index]}"
  name              = "${var.prefix}-vpc-gateway-${var.zones[count.index]}"
  resource_group_id = module.resource_group.resource_group_id
  tags              = var.tags
}

module "security_group" {
  source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/security-group?ref=v1.5.0"
  depends_on     = [module.vpc]
  create_security_group = false
  resource_group_id     = module.resource_group.resource_group_id
  security_group = "${var.prefix}-sg"
  security_group_rules = [
    {
      name = "allow_all_inbound"
      remote    = "0.0.0.0/0"
      direction = "inbound"
    }
  ]
}

locals {
  allow_subnet_cidr_inbound_rules = [
    for k, v in module.zone_subnet_addrs :
    {
      name        = "allow-traffic-subnet-${k}-inbound"
      action      = "allow"
      source      = v.base_cidr_block
      destination = "0.0.0.0/0"
      direction   = "inbound"
    }
  ]
  allow_subnet_cidr_outbound_rules = [
    for k, v in module.zone_subnet_addrs :
    {
      name        = "allow-traffic-subnet-${k}-outbound"
      action      = "allow"
      source      = "0.0.0.0/0"
      destination = v.base_cidr_block
      direction   = "outbound"
    }
  ]
  acl_rules = flatten(
    [
      local.allow_subnet_cidr_inbound_rules,
      local.allow_subnet_cidr_outbound_rules,
      var.acl_rules_list
    ]
  )
}

module "network_acl" {
  source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-vpc.git//modules/network-acl"
  name              = "${var.prefix}-vpc-acl"
  vpc_id            = module.vpc.vpc.vpc_id
  resource_group_id = module.resource_group.resource_group_id
  rules             = local.acl_rules
  tags              = var.tags
}

# OCP CLUSTER creation
module "ocp_base" {
  source               = "terraform-ibm-modules/base-ocp-vpc/ibm"
  version              = "3.35.10"
  cluster_name         = "${var.prefix}-vpc"
  resource_group_id    = module.resource_group.resource_group_id
  region               = var.region
  force_delete_storage = true
  vpc_id               = module.vpc.vpc.vpc_id
  vpc_subnets          = local.subnets
  worker_pools         = local.ocp_worker_pools
  tags                 = []
  use_existing_cos     = false
  # outbound required by cluster proxy
  disable_outbound_traffic_protection = true
}

# OCP CLUSTER creation
module "ocp_base" {
  source               = "terraform-ibm-modules/base-ocp-vpc/ibm"
  version              = "3.36.0"
  cluster_name         = "${var.prefix}-cluster"
  resource_group_id    = module.resource_group.resource_group_id
  region               = var.region
  force_delete_storage = true
  vpc_id               = module.vpc.vpc_id
  vpc_subnets          = module.vpc.subnets
  worker_pools         = local.ocp_worker_pools
  tags                 = []
  use_existing_cos     = false
  # outbound required by cluster proxy
  disable_outbound_traffic_protection = true
}

##############################################################################
# Init cluster config for helm and kubernetes providers
##############################################################################

data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = module.ocp_base.cluster_id
  resource_group_id = module.resource_group.resource_group_id
}

# Wait time to allow cluster refreshes components after provisioning
resource "time_sleep" "wait_45_seconds" {
  depends_on      = [data.ibm_container_cluster_config.cluster_config]
  create_duration = "45s"
}

########################################
## CIS to own public certificate
########################################

data "ibm_cis" "cis_instance" {
  name              = var.existing_cis_instance_name
  resource_group_id = var.existing_cis_instance_resource_group_id
}

######################################
# VPEs creation in the case of private for service endpoint
######################################

module "vpes" {
  source   = "terraform-ibm-modules/vpe-gateway/ibm"
  version  = "4.3.0"
  count    = var.service_endpoints == "private" ? 1 : 0
  region   = var.region
  prefix   = "vpe"
  vpc_name = "${var.prefix}-vpc"
  vpc_id   = module.vpc.vpc_id
  subnet_zone_list = [
    for index, subnet in module.vpc.subnets.transit : {
      name           = "${local.sm_region}-${index}"
      zone           = subnet.zone
      id             = subnet.id
      acl_name       = "acl"
      public_gateway = true
    }
  ]
  resource_group_id = module.resource_group.resource_group_id # pragma: allowlist secret
  cloud_services    = []
  cloud_service_by_crn = [
    {
      name = "iam-${var.region}"
      crn  = "crn:v1:bluemix:public:iam-svcs:global:::endpoint:private.iam.cloud.ibm.com"
    },
    {
      name = "sm-${var.region}"
      crn  = local.sm_crn
    }
  ]
  service_endpoints = "private"
  depends_on        = [ibm_resource_instance.secrets_manager]
}

##################################################################
# ESO deployment
##################################################################

module "external_secrets_operator" {
  source        = "../../"
  eso_namespace = var.eso_namespace

  eso_cluster_nodes_configuration = var.eso_deployment_nodes_configuration == null ? null : {
    nodeSelector = {
      label = "dedicated"
      value = var.eso_deployment_nodes_configuration
    }
    tolerations = {
      key      = "dedicated"
      operator = "Equal"
      value    = var.eso_deployment_nodes_configuration
      effect   = "NoExecute"
    }
  }

  depends_on = [
    kubernetes_namespace.apikey_namespaces, kubernetes_namespace.tp_namespaces
  ]
}

##################################################################
# Preliminary creation of namespaces to use for
# clusterstore and namespaced secretstores (to be configured with apikey authentication)
##################################################################

# Creating the namespaces for apikey authentication secrets stores
resource "kubernetes_namespace" "apikey_namespaces" {
  count = length(var.es_namespaces_apikey)
  metadata {
    name = var.es_namespaces_apikey[count.index]
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
  depends_on = [
    time_sleep.wait_45_seconds
  ]
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
    private = "192.168.0.0/20",
    transit = "192.168.16.0/20",
    edge    = "192.168.32.0/20"
  }
}

variable "new_bits" {
  description = "Number of additional address bits to use for numbering the new networks"
  type        = number
  default     = 2
}

variable "acl_rules_list" {
  description = "Access control list rule set per network zone"
  default =  [
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