provider "ibm" {
  ibmcloud_api_key      = var.ibmcloud_api_key
  visibility            = var.provider_visibility
  region                = local.cluster_region
  private_endpoint_type = (var.provider_visibility == "private" && local.cluster_region == "ca-mon") ? "vpe" : null
}

provider "ibm" {
  ibmcloud_api_key      = local.sm_ibmcloud_api_key
  visibility            = var.provider_visibility
  region                = local.sm_region
  alias                 = "ibm-sm"
  private_endpoint_type = (var.provider_visibility == "private" && local.sm_region == "ca-mon") ? "vpe" : null
}

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
  cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = data.ibm_container_cluster_config.cluster_config.host
    token                  = data.ibm_container_cluster_config.cluster_config.token
    cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
  }
}
