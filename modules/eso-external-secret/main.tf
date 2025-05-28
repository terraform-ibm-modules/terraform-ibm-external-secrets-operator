locals {
  # reloader annotation
  reloader_annotation = var.reloader_watching ? "'reloader.stakater.com/auto': 'true'" : "{}"
}

# secrets formatting
locals {
  # certificate secret templates and management
  is_certificate = can(regex("^imported_cert$|^public_cert$|^private_cert$", var.sm_secret_type))

  # dockerjsonconfig secrets chain flag
  is_dockerjsonconfig_chain = length(var.es_container_registry_secrets_chain) > 0 ? true : false

  # for certificate secrets public_cert and private_cert the id is the last part of the sm_secret_sm
  cert_remoteref_key = local.is_certificate ? "${var.sm_secret_type}/${var.sm_secret_id}" : ""
  # defining the template data structure according to the type of certificate
  # public and imported certificate template will contain intermediate field only if sm_certificate_has_intermediate flag is true and the certificate bundle flag is disabled
  public_cert_tls_template_data   = (var.sm_certificate_has_intermediate == true && var.sm_certificate_bundle == false) ? "tls.crt: \"{{ .certificate }}\\n{{ .intermediate }}\"\n            tls.key: '{{ .private_key }}'" : "tls.crt: '{{ .certificate}}'\n            tls.key: '{{ .private_key }}'"
  imported_cert_tls_template_data = (var.sm_certificate_has_intermediate == true && var.sm_certificate_bundle == false) ? "tls.crt: \"{{ .certificate }}\\n{{ .intermediate }}\"\n            tls.key: '{{ .private_key }}'" : "tls.crt: '{{ .certificate}}'\n            tls.key: '{{ .private_key }}'"
  private_cert_tls_template_data  = "tls.crt: '{{ .certificate}}'\n            tls.key: '{{ .private_key }}'"
  # defining the spec data structure according to the type of certificate
  # public and imported certificate template will contain intermediate field only if sm_certificate_has_intermediate flag is true
  public_certificate_spec_data   = (var.sm_certificate_has_intermediate == true && var.sm_certificate_bundle == false) ? "- secretKey: certificate\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: certificate\n      - secretKey: intermediate\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: intermediate\n      - secretKey: private_key\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: private_key" : "- secretKey: certificate\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: certificate\n      - secretKey: private_key\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: private_key"
  imported_certificate_spec_data = (var.sm_certificate_has_intermediate == true && var.sm_certificate_bundle == false) ? "- secretKey: certificate\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: certificate\n      - secretKey: intermediate\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: intermediate\n      - secretKey: private_key\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: private_key" : "- secretKey: certificate\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: certificate\n      - secretKey: private_key\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: private_key"
  private_certificate_spec_data  = "- secretKey: certificate\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: certificate\n      - secretKey: private_key\n        remoteRef:\n          key: ${local.cert_remoteref_key}\n          property: private_key"
  # definining the right structure to use according to the certificate type
  certificate_template  = local.is_certificate ? (var.sm_secret_type == "public_cert" ? local.public_cert_tls_template_data : (var.sm_secret_type == "imported_cert" ? local.imported_cert_tls_template_data : (var.sm_secret_type == "private_cert" ? local.private_cert_tls_template_data : ""))) : "" # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  certificate_spec_data = local.is_certificate ? (var.sm_secret_type == "public_cert" ? local.public_certificate_spec_data : (var.sm_secret_type == "imported_cert" ? local.imported_certificate_spec_data : (var.sm_secret_type == "private_cert" ? local.private_certificate_spec_data : ""))) : ""    # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value

  # dockerjson format
  docker_user     = var.sm_secret_type == "username_password" ? "{{ .username }}" : "iamapikey" # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  docker_password = var.sm_secret_type == "username_password" ? "{{ .password }}" : "{{ .secretid }}"

  # setting data_type according to the kube secret and the SM secret types
  # if kube secret type is opaque && SM secret type arbitrary or iam_credentials -> var.es_kubernetes_secret_data_key
  # if kube secret type is opaque && SM secret type username_password -> data_type = .dockerconfigjson
  # if kube secret type is opaque && SM secret type != username_password arbitrary and iam_credentials (so kv or the certificate types) -> not setting anything here but handled in related sections
  # if kube secret type is not opaque && kube secret type is dockerconfigjson -> data_type =  .dockerconfigjson
  # if kube secret type is not opaque && if kube secret type is not dockerconfigjson -> not setting here
  data_type = var.es_kubernetes_secret_type == "opaque" ? ((var.sm_secret_type == "arbitrary" || var.sm_secret_type == "iam_credentials") ? var.es_kubernetes_secret_data_key : (var.sm_secret_type == "username_password") ? ".dockerconfigjson" : "") : (var.es_kubernetes_secret_type == "dockerconfigjson" ? ".dockerconfigjson" : "")

  # setting data_payload for dockerconfigjson according to the value of var.es_container_registry_email
  # if es_kubernetes_secret_type = dockerconfigjson -> setting payload according to the fields available
  # if es_kubernetes_secret_type != dockerconfigjson -> data_payload = {{ .secretid }}
  data_payload = var.es_kubernetes_secret_type == "dockerconfigjson" && var.es_container_registry_email != null ? jsonencode({ "auths" : { (var.es_container_registry) : { "email" : (var.es_container_registry_email), "username" : (local.docker_user), "password" : (local.docker_password) } } }) : (var.es_kubernetes_secret_type == "dockerconfigjson" && var.es_container_registry_email == null ? jsonencode({ "auths" : { (var.es_container_registry) : { "username" : (local.docker_user), "password" : (local.docker_password) } } }) : "{{ .secretid }}") # checkov:skip=CKV_SECRET_6:does not require high entropy string as is static value

  # final data field format according to the secret type
  # only in the case sm_secret_type is username_password and kube secret type is opaque -> data = username : '{{ .username }}'\n            password : '{{ .password }}
  # in all the other cases data is the resulting data_type : data_payload
  username_password_opaque_data = "username : '{{ .username }}'\n            password : '{{ .password }}'"
  data                          = var.sm_secret_type == "username_password" && var.es_kubernetes_secret_type == "opaque" ? local.username_password_opaque_data : "${local.data_type} : '${local.data_payload}'" # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value

  # setting value for template type field according to the var.es_kubernetes_secret_type value
  es_kubernetes_secret_type = var.es_kubernetes_secret_type == "dockerconfigjson" ? "kubernetes.io/dockerconfigjson" : (var.es_kubernetes_secret_type == "tls" ? "kubernetes.io/tls" : "Opaque")

  # setting remote_ref field value according to the secret type
  # for sm secrets types iam_credentials and kv the remoteref is sm_secret_type/sm_secret_id, for arbitrary is only sm_secret_id
  # if is_dockerjsonconfig_chain is true it is set to empty as not used
  es_remoteref_key = local.is_dockerjsonconfig_chain == false ? (var.sm_secret_type == "iam_credentials" || var.sm_secret_type == "kv" ? "${var.sm_secret_type}/${var.sm_secret_id}" : var.sm_secret_id) : "" # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value

  # dockerconfigjson config for chain of secrets - building a map for all the registries
  data_payload_chain_map = local.is_dockerjsonconfig_chain == true ? {
    "auths" : {
      for index, element in var.es_container_registry_secrets_chain :
      element.es_container_registry => (element.es_container_registry_email != null && element.es_container_registry_email != "") ?
      {
        "username" : "iamapikey", "password" : "{{ .secretid_${index} }}", "email" : (element.es_container_registry_email)
      }
      :
      (element.trusted_profile != null && element.trusted_profile != "" && var.sm_secret_type == "trusted_profile") ?
      {
        "username" : element.trusted_profile, "password" : "{{ .secretid_${index} }}"
      } :
      {
        "username" : "iamapikey", "password" : "{{ .secretid_${index} }}"
      }
    }
  } : {}

  # in order to have the content correctly mapped it needs to apply jsonencode twice
  encodedchain = jsonencode(jsonencode(local.data_payload_chain_map))
  data_chain   = ".dockerconfigjson : ${local.encodedchain}"

  # helm chart details
  helm_raw_chart_name    = "raw"
  helm_raw_chart_version = "0.2.5"

  # if the scope is namespace the secret store kind is SecretStore while is ClusterSecretStore in all the other cases
  secret_store_ref_kind = var.eso_store_scope != "namespace" ? "ClusterSecretStore" : "SecretStore"

  # if var.es_helm_rls_namespace is not set the namespace is set to es_kubernetes_namespace (default logic)
  es_helm_rls_namespace = var.es_helm_rls_namespace != null ? var.es_helm_rls_namespace : var.es_kubernetes_namespace

  # key-value secret management
  is_kv = can(regex("^kv$", var.sm_secret_type))

  # setting up the remoteref property for kv
  kv_remoteref_property = var.sm_kv_keyid != null ? var.sm_kv_keyid : (var.sm_kv_keypath != null ? var.sm_kv_keypath : "")

  # kube secret name
  helm_secret_name = substr(join("-", [var.es_kubernetes_namespace, var.es_helm_rls_name]), 0, 52)
}

### Define kubernetes secret to be installed in cluster for sm_secret_type iam_credentials or arbitrary
resource "helm_release" "kubernetes_secret" {
  count     = (var.sm_secret_type == "iam_credentials" || var.sm_secret_type == "arbitrary" || var.sm_secret_type == "trusted_profile") && local.is_dockerjsonconfig_chain == false ? 1 : 0
  name      = local.helm_secret_name
  namespace = local.es_helm_rls_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: "${var.es_kubernetes_secret_name}"
          namespace: "${var.es_kubernetes_namespace}"
        spec:
          refreshInterval: ${var.es_refresh_interval}
          secretStoreRef:
            name: "${var.eso_store_name}"
            kind: "${local.secret_store_ref_kind}"
          target:
            name: "${var.es_kubernetes_secret_name}"
            template:
              engineVersion: v2
              type: "${local.es_kubernetes_secret_type}"
              metadata:
                annotations:
                  ${local.reloader_annotation}
              data:
                ${local.data}
          data:
          - secretKey: secretid
            remoteRef:
              key: "${local.es_remoteref_key}"
    EOF
  ]
}

### Define kubernetes secret to be installed in cluster for sm_secret_type iam_credentials and kubernetes secret type dockerjsonconfig and configured with a chain of secrets
resource "helm_release" "kubernetes_secret_chain_list" {
  count     = local.is_dockerjsonconfig_chain == true ? 1 : 0
  name      = local.helm_secret_name
  namespace = local.es_helm_rls_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: "${var.es_kubernetes_secret_name}"
          namespace: "${var.es_kubernetes_namespace}"
        spec:
          refreshInterval: ${var.es_refresh_interval}
          secretStoreRef:
            name: "${var.eso_store_name}"
            kind: "${local.secret_store_ref_kind}"
          target:
            name: "${var.es_kubernetes_secret_name}"
            template:
              engineVersion: v2
              type: "${local.es_kubernetes_secret_type}"
              metadata:
                annotations:
                  ${local.reloader_annotation}
              data:
                ${local.data_chain}
          data:
%{for index, element in var.es_container_registry_secrets_chain~}
          - secretKey: secretid_${index}
            remoteRef:
              key: "${var.sm_secret_type == "trusted_profile" ? "iam_credentials/${element.sm_secret_id}" : "${var.sm_secret_type}/${element.sm_secret_id}"}"
%{endfor~}
    EOF
  ]
}


### Define kubernetes secret to be installed in cluster for opaque secret type based on SM user credential secret type
resource "helm_release" "kubernetes_secret_user_pw" {
  count     = var.sm_secret_type == "username_password" ? 1 : 0
  name      = local.helm_secret_name
  namespace = var.es_kubernetes_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: "${var.es_kubernetes_secret_name}"
          namespace: "${var.es_kubernetes_namespace}"
        spec:
          refreshInterval: ${var.es_refresh_interval}
          secretStoreRef:
            name: "${var.eso_store_name}"
            kind: "${local.secret_store_ref_kind}"
          target:
            name: "${var.es_kubernetes_secret_name}"
            template:
              engineVersion: v2
              type: "${local.es_kubernetes_secret_type}"
              metadata:
                annotations:
                  ${local.reloader_annotation}
              data:
                ${local.data}
          data:
          - secretKey: username
            remoteRef:
              key: "username_password/${var.sm_secret_id}"
              property: username
          - secretKey: password
            remoteRef:
              key: "username_password/${var.sm_secret_id}"
              property: password
    EOF
  ]
}

### Define kubernetes secret to be installed in cluster for certificate secret based on SM certificate secret type
resource "helm_release" "kubernetes_secret_certificate" {
  count     = local.is_certificate ? 1 : 0 #checkov:skip=CKV_SECRET_6
  name      = local.helm_secret_name
  namespace = var.es_kubernetes_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: "${var.es_kubernetes_secret_name}"
          namespace: "${var.es_kubernetes_namespace}"
        spec:
          refreshInterval: ${var.es_refresh_interval}
          secretStoreRef:
            name: "${var.eso_store_name}"
            kind: "${local.secret_store_ref_kind}"
          target:
            name: "${var.es_kubernetes_secret_name}"
            template:
              engineVersion: v2
              type: "${local.es_kubernetes_secret_type}"
              metadata:
                annotations:
                  ${local.reloader_annotation}
              data:
                ${local.certificate_template}
          data:
          ${local.certificate_spec_data}
    EOF
  ]
}

### Define kubernetes secret to be installed in cluster for key-value secret based on SM kv secret type based on keyid or key path
resource "helm_release" "kubernetes_secret_kv_key" {
  count     = local.is_kv && local.kv_remoteref_property != "" ? 1 : 0
  name      = local.helm_secret_name
  namespace = var.es_kubernetes_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: "${var.es_kubernetes_secret_name}"
          namespace: "${var.es_kubernetes_namespace}"
        spec:
          refreshInterval: ${var.es_refresh_interval}
          secretStoreRef:
            name: "${var.eso_store_name}"
            kind: "${local.secret_store_ref_kind}"
          target:
            name: "${var.es_kubernetes_secret_name}"
            template:
              engineVersion: v2
              type: "${local.es_kubernetes_secret_type}"
              metadata:
                annotations:
                  ${local.reloader_annotation}
              data:
                secret: "{{ .${local.kv_remoteref_property} }}"
          data:
          - secretKey: "${local.kv_remoteref_property}"
            remoteRef:
              key: "${local.es_remoteref_key}"
              property: "${local.kv_remoteref_property}"
    EOF
  ]
}

### Define kubernetes secret to be installed in cluster for key-value secret based on SM kv secret type pulling all the keys structure
resource "helm_release" "kubernetes_secret_kv_all" {
  count     = local.is_kv && local.kv_remoteref_property == "" ? 1 : 0
  name      = local.helm_secret_name
  namespace = var.es_kubernetes_namespace
  chart     = "${path.module}/../../chart/${local.helm_raw_chart_name}"
  version   = local.helm_raw_chart_version
  timeout   = 600
  values = [
    <<-EOF
    resources:
      - apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: "${var.es_kubernetes_secret_name}"
          namespace: "${var.es_kubernetes_namespace}"
        spec:
          refreshInterval: ${var.es_refresh_interval}
          secretStoreRef:
            name: "${var.eso_store_name}"
            kind: "${local.secret_store_ref_kind}"
          target:
            name: "${var.es_kubernetes_secret_name}"
            template:
              engineVersion: v2
              type: "${local.es_kubernetes_secret_type}"
              metadata:
                annotations:
                  ${local.reloader_annotation}
              data:
                secret: '{{ .keys }}'
          data:
          - secretKey: keys
            remoteRef:
              key: "${local.es_remoteref_key}"
    EOF
  ]
}
