data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = var.cluster_name_id
  resource_group_id = module.resource_group.resource_group_id
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
}

data "ibm_iam_auth_token" "token_data" {}

provider "restapi" {
  uri                  = "https:"
  write_returns_object = true
  debug                = false # set to true to show detailed logs, but use carefully as it might print API key values.
  headers = {
    Accept        = "application/json"
    Authorization = data.ibm_iam_auth_token.token_data.iam_access_token
    Content-Type  = "application/json"
  }
}

provider "kubernetes" {
  client_certificate     = data.ibm_container_cluster_config.cluster_config.admin_certificate
  client_key             = data.ibm_container_cluster_config.cluster_config.admin_key
  cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
}


provider "helm" {
  kubernetes = {
    client_certificate     = data.ibm_container_cluster_config.cluster_config.admin_certificate
    client_key             = data.ibm_container_cluster_config.cluster_config.admin_key
    cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
    host                   = data.ibm_container_cluster_config.cluster_config.host
    token                  = data.ibm_container_cluster_config.cluster_config.token
  }
}
