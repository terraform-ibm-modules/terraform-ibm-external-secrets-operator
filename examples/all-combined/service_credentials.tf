##################################################################
# Service Credentials Secret Configuration
##################################################################

# Create Redis database instance
resource "ibm_database" "redis_instance" {
  name              = "${var.prefix}-redis-db"
  plan              = "standard"
  location          = var.region
  service           = "databases-for-redis"
  resource_group_id = module.resource_group.resource_group_id
  service_endpoints = "public"

  group {
    group_id = "member"
    memory {
      allocation_mb = 8192
    }
    disk {
      allocation_mb = 20480
    }
  }

  tags = var.resource_tags
}

# Create secret group for service credentials
module "service_credentials_secret_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.5.3"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-service-creds-secret-group"
  secret_group_description = "Secret group for service credentials"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create IAM authorization policy between Secrets Manager and Redis
resource "ibm_iam_authorization_policy" "sm_redis_policy" {
  source_service_name         = "secrets-manager"
  source_resource_instance_id = local.sm_guid
  target_service_name         = "databases-for-redis"
  target_resource_instance_id = ibm_database.redis_instance.guid
  roles                       = ["Key Manager"]
}

# Wait for authorization policy to propagate
resource "time_sleep" "wait_for_authorization" {
  depends_on      = [ibm_iam_authorization_policy.sm_redis_policy]
  create_duration = "30s"
}

# Create service credentials secret in Secrets Manager
resource "ibm_sm_service_credentials_secret" "redis_service_credentials" {
  depends_on      = [time_sleep.wait_for_authorization]
  instance_id     = local.sm_guid
  region          = local.sm_region
  name            = "${var.prefix}-redis-service-credentials"
  description     = "Service credentials for Redis database"
  secret_group_id = module.service_credentials_secret_group.secret_group_id
  ttl             = "7776000" # 90 days

  source_service {
    instance {
      crn = ibm_database.redis_instance.id
    }
    role {
      crn = "crn:v1:bluemix:public:iam::::serviceRole:Manager"
    }
  }

  provider = ibm.ibm-sm
}

# Create Service ID for accessing service credentials
resource "ibm_iam_service_id" "service_creds_reader" {
  name        = "${var.prefix}-service-creds-reader"
  description = "Service ID to read service credentials from Secrets Manager"
}

# Create policy for Service ID to access the secret group
resource "ibm_iam_service_policy" "service_creds_reader_policy" {
  iam_service_id = ibm_iam_service_id.service_creds_reader.id
  roles          = ["SecretsReader", "Viewer"]

  resources {
    service              = "secrets-manager"
    resource_instance_id = local.sm_guid
    resource_type        = "secret-group"
    resource             = module.service_credentials_secret_group.secret_group_id
  }
}

# Generate API key for the Service ID
resource "ibm_iam_service_api_key" "service_creds_reader_apikey" {
  name           = "${var.prefix}-service-creds-reader-apikey"
  iam_service_id = ibm_iam_service_id.service_creds_reader.iam_id
  description    = "API key for service credentials reader"
}

# Create namespace for service credentials external secret
resource "kubernetes_namespace_v1" "service_creds_namespace" {
  metadata {
    name = "service-credential-test-ns"
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

# Create SecretStore in the namespace using Service ID API key
module "eso_service_creds_secretstore" {
  depends_on                  = [module.external_secrets_operator]
  source                      = "../../modules/eso-secretstore"
  eso_authentication          = "api_key"
  region                      = local.sm_region
  sstore_namespace            = kubernetes_namespace_v1.service_creds_namespace.metadata[0].name
  sstore_secrets_manager_guid = local.sm_guid
  sstore_store_name           = "service-creds-store"
  sstore_secret_apikey        = ibm_iam_service_api_key.service_creds_reader_apikey.apikey
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store-service-creds"
  sstore_secret_name          = "service-creds-apikey-secret"
}

# Create external secret for service credentials
module "external_secret_service_credentials" {
  depends_on = [
    module.eso_service_creds_secretstore,
    ibm_sm_service_credentials_secret.redis_service_credentials
  ]
  source                    = "../../modules/eso-external-secret"
  eso_store_scope           = "namespace"
  es_kubernetes_namespace   = kubernetes_namespace_v1.service_creds_namespace.metadata[0].name
  es_kubernetes_secret_name = "service-credential-test-secret"
  es_kubernetes_secret_type = "opaque"
  sm_secret_type            = "service_credentials"
  sm_secret_id              = ibm_sm_service_credentials_secret.redis_service_credentials.secret_id
  eso_store_name            = "service-creds-store"
  es_refresh_interval       = "5m"
  es_helm_rls_name          = "sc-helm"

  sm_service_credentials_mappings = {
    username = "(.credentials | fromJson).connection.rediss.authentication.username"
    host     = "((.credentials | fromJson).connection.rediss.hosts | first).hostname"
  }
}