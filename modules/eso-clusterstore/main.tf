locals {
  helm_raw_chart_name    = "raw"
  helm_raw_chart_version = "0.2.5"

  # endpoints definition according to endpoints to use are private or public (var.service_endpoints)
  iam_endpoint                           = "${var.service_endpoints == "private" ? "private." : ""}iam.cloud.ibm.com"
  regional_endpoint                      = var.service_endpoints == "private" ? "private.${var.region}" : var.region
  cluster_store_secrets_manager_endpoint = "${var.clusterstore_secrets_manager_guid}.${local.regional_endpoint}.secrets-manager.appdomain.cloud"
}

### creating secret to store apikey to authenticate on secretsmanager for apikey authentication
resource "kubernetes_secret" "eso_clusterstore_secret" {
  count = var.eso_authentication == "api_key" ? 1 : 0
  metadata {
    name      = var.clusterstore_secret_name
    namespace = var.eso_namespace #checkov:skip=CKV_K8S_21
  }

  data = {
    apiKey = var.clusterstore_secret_apikey
  }
  type = "opaque"
}


### ClusterSecretStore used to connect with SM instance for clusterstore and authentication is through apikey

# define cluster secret store for cluster scope and apikey auth
resource "helm_release" "cluster_secret_store_apikey" {
  count        = var.eso_authentication == "api_key" ? 1 : 0
  name         = "${var.clusterstore_helm_rls_name}-apikey"
  namespace    = var.eso_namespace
  chart        = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version      = local.helm_raw_chart_version
  timeout      = 600
  force_update = true
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ClusterSecretStore
        metadata:
          name: "${var.clusterstore_name}"
        spec:
          provider:
            ibm:
              serviceUrl: "https://${local.cluster_store_secrets_manager_endpoint}"
              auth:
                secretRef:
                  secretApiKeySecretRef:
                    name: "${var.clusterstore_secret_name}"
                    key: apiKey
                    namespace: "${var.eso_namespace}"
    EOF
  ]

  depends_on = [
    kubernetes_secret.eso_clusterstore_secret
  ]
}

# define cluster secret store for cluster scope and trusted store auth
# ContainerAuth with CRI based authentication
resource "helm_release" "cluster_secret_store_tp" {
  count        = var.eso_authentication == "trusted_profile" ? 1 : 0
  name         = "${var.clusterstore_helm_rls_name}-tp"
  namespace    = var.eso_namespace
  chart        = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version      = local.helm_raw_chart_version
  timeout      = 600
  force_update = true
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ClusterSecretStore
        metadata:
          name: "${var.clusterstore_name}"
        spec:
          provider:
            ibm:
              serviceUrl: "https://${local.cluster_store_secrets_manager_endpoint}"
              auth:
                containerAuth:
                  profile: "${var.clusterstore_trusted_profile_name}"
                  iamEndpoint: "https://${local.iam_endpoint}"
                  tokenLocation: /var/run/secrets/tokens/sa-token
    EOF
  ]
}
