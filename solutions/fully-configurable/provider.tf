provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = local.cluster_region
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = local.sm_region
  alias            = "ibm-sm"
}

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
  cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = data.ibm_container_cluster_config.cluster_config.host
    token                  = data.ibm_container_cluster_config.cluster_config.token
    cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
  }
}
