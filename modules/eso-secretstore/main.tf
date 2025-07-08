locals {
  helm_raw_chart_name    = "raw"
  helm_raw_chart_version = "0.2.5"
  # endpoints definition according to endpoints to use are private or public (var.service_endpoints)
  iam_endpoint      = "${var.service_endpoints == "private" ? "private." : ""}iam.cloud.ibm.com"
  regional_endpoint = var.service_endpoints == "private" ? "private.${var.region}" : var.region
}

### creating secret to store apikey to authenticate on secretsmanager for apikey authentication
resource "kubernetes_secret" "eso_secretsstore_secret" {
  count = var.eso_authentication == "api_key" ? 1 : 0
  metadata {
    name      = var.sstore_secret_name
    namespace = var.sstore_namespace #checkov:skip=CKV_K8S_21
  }

  data = {
    apiKey = var.sstore_secret_apikey
  }
  type = "opaque"
}

### Define secret store used to connect with SM instance for apikey auth
resource "helm_release" "external_secret_store_apikey" {
  count     = var.eso_authentication == "api_key" ? 1 : 0
  name      = substr(join("-", [var.sstore_namespace, "ak", var.sstore_helm_rls_name]), 0, 52)
  namespace = var.sstore_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: SecretStore
        metadata:
          name: "${var.sstore_store_name}"
          namespace: "${var.sstore_namespace}"
        spec:
          provider:
            ibm:
              serviceUrl: "https://${var.sstore_secrets_manager_guid}.${local.regional_endpoint}.secrets-manager.appdomain.cloud"
              auth:
                secretRef:
                  secretApiKeySecretRef:
                    name: "${var.sstore_secret_name}"
                    key: apiKey
    EOF
  ]
}

# Trusted profile authentication Use ContainerAuth with CRI based authentication (trusted profile support)
resource "helm_release" "external_secret_store_tp" {
  count     = var.eso_authentication == "trusted_profile" ? 1 : 0
  name      = substr(join("-", [var.sstore_namespace, "tp", var.sstore_helm_rls_name]), 0, 52)
  namespace = var.sstore_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: SecretStore
        metadata:
          name: "${var.sstore_store_name}"
          namespace: "${var.sstore_namespace}"
        spec:
          provider:
            ibm:
              serviceUrl: "https://${var.sstore_secrets_manager_guid}.${local.regional_endpoint}.secrets-manager.appdomain.cloud"
              auth:
                containerAuth:
                  profile: "${var.sstore_trusted_profile_name}"
                  iamEndpoint: "https://${local.iam_endpoint}"
                  tokenLocation: /var/run/secrets/tokens/sa-token
    EOF
  ]
}
