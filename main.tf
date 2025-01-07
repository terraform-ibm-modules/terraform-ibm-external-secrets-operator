##############################################################################
# External Secrets Sync Module
#
# Module for deploying External Secret Operator (ESO) and use it to create and synchronize Kubernetes secrets into clusters based on Secrets-Manager secrets.
##############################################################################

## Install ESO

locals {
  eso_digest = "v0.11.0-ubi@sha256:b5f685b86cf684020e863c6c2ed91e8a79cad68260d7149ddee073ece2573d6f"

  eso_image_tag_digest = var.eso_image_tag_digest != null || var.eso_image_tag_digest != "" ? var.eso_image_tag_digest : local.eso_digest
  eso_image_repo       = var.eso_image_repo

  reloader_image_tag_digest = "v1.2.1-ubi@sha256:78d3b7269d00df1b9550584dba817299b5842c48038db1f1603255914033307f" # datasource: icr.io/ibm-iac/reloader
  reloader_image_repo       = "icr.io/ibm-iac/reloader"
}

# creating namespace to deploy ESO into RedHat ServiceMesh
module "eso_namespace" {
  count   = var.eso_namespace != null ? 1 : 0
  source  = "terraform-ibm-modules/namespace/ibm"
  version = "1.0.2"
  namespaces = [
    {
      name = var.eso_namespace
      metadata = {
        name = var.eso_namespace
        labels = {
        }
        annotations = {
          "istio-injection" = var.eso_enroll_in_servicemesh == true ? "enabled" : null
        }
      }
    }
  ]
}

# loading existing eso namespace
data "kubernetes_namespace" "existing_eso_namespace" {
  count = var.existing_eso_namespace != null ? 1 : 0
  metadata {
    name = var.existing_eso_namespace
  }
}

locals {
  # namespace to use for eso. If both eso_namespace and existing_eso_namespace are not null, eso_namespace takes the precedence
  eso_namespace = var.eso_namespace != null ? var.eso_namespace : data.kubernetes_namespace.existing_eso_namespace[0].metadata[0].name
}

locals {
  eso_helm_release_values_cri = <<-EOF
installCRDs: true
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - "ALL"
  enabled: true
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  seccompProfile:
    type: "RuntimeDefault"
podAnnotations:
%{for key, value in var.eso_pod_configuration.annotations.external_secrets}    "${key}": "${value}" %{endfor}
%{if var.eso_enroll_in_servicemesh == true}
  sidecar.istio.io/inject: "true"
  sidecar.istio.io/rewriteAppHTTPProbers: "true"
%{endif}
podLabels:
%{if var.eso_enroll_in_servicemesh == true}    app: external-secrets-operator %{endif}
%{for key, value in var.eso_pod_configuration.labels.external_secrets}    "${key}": "${value}" %{endfor}
%{if var.eso_enroll_in_servicemesh == true}
extraEnv:
- name: KUBERNETES_SERVICE_HOST
  value: kubernetes.default.svc.cluster.local
%{endif}
extraVolumes:
- name: sa-token
  projected:
      defaultMode: 0644
      sources:
      - serviceAccountToken:
          path: sa-token
          expirationSeconds: 3600
          audience: iam
extraVolumeMounts:
- mountPath: /var/run/secrets/tokens
  name: sa-token
webhook:
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - "ALL"
    enabled: true
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: "RuntimeDefault"
  podAnnotations:
    %{for key, value in var.eso_pod_configuration.annotations.external_secrets_webhook}    "${key}": "${value}" %{endfor}
    %{if var.eso_enroll_in_servicemesh == true}
    sidecar.istio.io/inject: "true"
    sidecar.istio.io/rewriteAppHTTPProbers: "true"
    %{endif}
  podLabels:
    %{if var.eso_enroll_in_servicemesh == true}    app: external-secrets-operator %{endif}
    %{for key, value in var.eso_pod_configuration.labels.external_secrets_webhook}    "${key}": "${value}" %{endfor}
  %{if var.eso_enroll_in_servicemesh == true}
  extraEnv:
  - name: KUBERNETES_SERVICE_HOST
    value: kubernetes.default.svc.cluster.local
  %{endif}
  extraVolumes:
  - name: sa-token
    projected:
      defaultMode: 0644
      sources:
      - serviceAccountToken:
          path: sa-token
          expirationSeconds: 3600
          audience: iam
  extraVolumeMounts:
  - mountPath: /var/run/secrets/tokens
    name: sa-token
certController:
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - "ALL"
    enabled: true
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: "RuntimeDefault"
  podAnnotations:
    %{for key, value in var.eso_pod_configuration.annotations.external_secrets_cert_controller}    "${key}": "${value}" %{endfor}
    %{if var.eso_enroll_in_servicemesh == true}
    sidecar.istio.io/inject: "true"
    sidecar.istio.io/rewriteAppHTTPProbers: "true"
    %{endif}
  podLabels:
    %{if var.eso_enroll_in_servicemesh == true}    app: external-secrets-operator %{endif}
    %{for key, value in var.eso_pod_configuration.labels.external_secrets_cert_controller}    "${key}": "${value}" %{endfor}
  %{if var.eso_enroll_in_servicemesh == true}
  extraEnv:
  - name: KUBERNETES_SERVICE_HOST
    value: kubernetes.default.svc.cluster.local
  %{endif}
EOF

  eso_helm_release_values_workerselector = var.eso_cluster_nodes_configuration == null ? "" : <<-EOF
nodeSelector: { ${var.eso_cluster_nodes_configuration.nodeSelector.label}: ${var.eso_cluster_nodes_configuration.nodeSelector.value} }
tolerations:
- key: ${var.eso_cluster_nodes_configuration.tolerations.key}
  operator: ${var.eso_cluster_nodes_configuration.tolerations.operator}
  value: ${var.eso_cluster_nodes_configuration.tolerations.value}
  effect: ${var.eso_cluster_nodes_configuration.tolerations.effect}
webhook:
  nodeSelector: { ${var.eso_cluster_nodes_configuration.nodeSelector.label}: ${var.eso_cluster_nodes_configuration.nodeSelector.value} }
  tolerations:
  - key: ${var.eso_cluster_nodes_configuration.tolerations.key}
    operator: ${var.eso_cluster_nodes_configuration.tolerations.operator}
    value: ${var.eso_cluster_nodes_configuration.tolerations.value}
    effect: ${var.eso_cluster_nodes_configuration.tolerations.effect}
certController:
  nodeSelector: { ${var.eso_cluster_nodes_configuration.nodeSelector.label}: ${var.eso_cluster_nodes_configuration.nodeSelector.value} }
  tolerations:
  - key: ${var.eso_cluster_nodes_configuration.tolerations.key}
    operator: ${var.eso_cluster_nodes_configuration.tolerations.operator}
    value: ${var.eso_cluster_nodes_configuration.tolerations.value}
    effect: ${var.eso_cluster_nodes_configuration.tolerations.effect}
EOF
}

resource "helm_release" "external_secrets_operator" {
  depends_on = [module.eso_namespace, data.kubernetes_namespace.existing_eso_namespace]

  name       = "external-secrets"
  namespace  = local.eso_namespace
  chart      = "external-secrets"
  version    = "0.12.1"
  wait       = true
  repository = "https://charts.external-secrets.io"

  set {
    name  = "image.repository"
    type  = "string"
    value = local.eso_image_repo
  }

  set {
    name  = "image.tag"
    type  = "string"
    value = local.eso_image_tag_digest
  }

  set {
    name  = "webhook.image.repository"
    type  = "string"
    value = local.eso_image_repo
  }

  set {
    name  = "webhook.image.tag"
    type  = "string"
    value = local.eso_image_tag_digest
  }

  set {
    name  = "certController.image.repository"
    type  = "string"
    value = local.eso_image_repo
  }

  set {
    name  = "certController.image.tag"
    type  = "string"
    value = local.eso_image_tag_digest
  }

  # The following mounts are needed for the CRI based authentication with Trusted Profiles
  values = [local.eso_helm_release_values_cri, local.eso_helm_release_values_workerselector]
}

resource "helm_release" "pod_reloader" {
  depends_on = [module.eso_namespace, data.kubernetes_namespace.existing_eso_namespace]
  count      = var.reloader_deployed == true ? 1 : 0
  name       = "reloader"
  namespace  = local.eso_namespace
  chart      = "oci://icr.io/ibm-iac-charts/reloader"
  version    = "1.2.0"
  wait       = true

  # Set the deployment image name and tag
  set {
    name  = "reloader.deployment.image.name"
    type  = "string"
    value = local.reloader_image_repo
  }

  set {
    name  = "reloader.deployment.image.tag"
    type  = "string"
    value = local.reloader_image_tag_digest
  }

  # Set reload strategy
  set {
    name  = "reloader.reloadStrategy"
    type  = "string"
    value = var.reloader_reload_strategy
  }

  # Set namespaces to ignore
  dynamic "set" {
    for_each = var.reloader_namespaces_to_ignore != null ? [1] : []
    content {
      name  = "reloader.namespacesToIgnore"
      value = var.reloader_namespaces_to_ignore
    }
  }

  # Set resources to ignore
  dynamic "set" {
    for_each = var.reloader_resources_to_ignore != null ? [1] : []
    content {
      name  = "reloader.resourcesToIgnore"
      value = var.reloader_resources_to_ignore
    }
  }

  # Set watchGlobally based on conditions
  set {
    name  = "reloader.watchGlobally"
    value = var.reloader_namespaces_selector == null && var.reloader_resource_label_selector == null ? true : false
  }

  # Set ignoreSecrets and ignoreConfigMaps
  set {
    name  = "reloader.ignoreSecrets"
    value = var.reloader_ignore_secrets
  }

  set {
    name  = "reloader.ignoreConfigMaps"
    value = var.reloader_ignore_configmaps
  }

  # Set OpenShift and Argo Rollouts options
  set {
    name  = "reloader.isOpenshift"
    value = var.reloader_is_openshift
  }
  # Set runAsUser to null if isOpenShift is true
  dynamic "set" {
    for_each = var.reloader_is_openshift ? [1] : []
    content {
      name  = "reloader.deployment.securityContext.runAsUser"
      value = "null"
    }
  }

  set {
    name  = "reloader.podMonitor.enabled"
    value = var.reloader_pod_monitor_metrics
  }
  dynamic "set" {
    for_each = var.reloader_log_format == "json" ? [1] : []
    content {
      name  = "reloader.logFormat"
      value = var.reloader_log_format
    }
  }
  set {
    name  = "reloader.isArgoRollouts"
    value = var.reloader_is_argo_rollouts
  }

  # Set reloadOnCreate and syncAfterRestart options
  set {
    name  = "reloader.reloadOnCreate"
    value = var.reloader_reload_on_create
  }

  set {
    name  = "reloader.syncAfterRestart"
    value = var.reloader_sync_after_restart
  }

  # Set the values attribute conditionally
  values = var.reloader_custom_values != null ? yamldecode(var.reloader_custom_values) : []
}
