## Terraform IBM External Secrets Operator module

[![Graduated (Supported)](https://img.shields.io/badge/Status-Graduated%20(Supported)-brightgreen)](https://terraform-ibm-modules.github.io/documentation/#/badge-status)
[![latest release](https://img.shields.io/github/v/release/terraform-ibm-modules/terraform-ibm-external-secrets-operator?logo=GitHub&sort=semver)](https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator/releases/latest)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com/)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)

This module automates the installation and configuration of the [External Secrets Operator](https://external-secrets.io/) in a cluster.

<!-- Below content is automatically populated via pre-commit hook -->
<!-- BEGIN OVERVIEW HOOK -->
## Overview
* [terraform-ibm-external-secrets-operator](#terraform-ibm-external-secrets-operator)
* [Submodules](./modules)
    * [eso-clusterstore](./modules/eso-clusterstore)
    * [eso-external-secret](./modules/eso-external-secret)
    * [eso-secretstore](./modules/eso-secretstore)
    * [eso-trusted-profile](./modules/eso-trusted-profile)
* [Examples](./examples)
    * [Basic Example](./examples/basic)
    * [Example that uses trusted profiles (container authentication)](./examples/trusted-profiles-authentication)
    * [Example to deploy the External Secret Operator and to create a different set of resources in terms of secrets, secret groups, stores and auth configurations](./examples/all-combined)
    * [ImagePull API key Secrets Manager](./examples/all-combined/imagepull-apikey-secrets-manager)
* [Contributing](#contributing)
<!-- END OVERVIEW HOOK -->

<!-- Match this heading to the name of the root level module (the repo name) -->
## External Secrets Operator module

External Secrets Operator synchronizes secrets in the Kubernetes cluster with secrets that are mapped in [Secrets Manager](https://cloud.ibm.com/docs/secrets-manager).

The module provides the following features:
- Install and configure External Secrets Operator (ESO).
- Customise External Secret Operator deployment on specific cluster workers by configuration appropriate NodeSelector and Tolerations in the ESO helm release [More details below](#customise-eso-deployment-on-specific-cluster-nodes)

The submodules automate the configuration of an operator, providing the following features:
- Deploy and configure [ClusterSecretStore](https://external-secrets.io/latest/api/clustersecretstore/) resources for cluster scope secrets store [eso-clusterstore](./eso-clusterstore/README.md)
- Deploy and configure [SecretStore](https://external-secrets.io/latest/api/secretstore/) resources for namespace scope secrets store [eso-secretstore](./eso-secretstore/README.md)
- Leverage on two authentication methods to be configured on the single stores instances:
  - IAM apikey standard authentication
  - IAM Trusted profile: in conjunction with [`eso-trusted-profile`](./eso-trusted-profile/README.md) submodule, which allows to create one or more trusted profiles to use with the ESO module for trusted profile authentication.
- Configure the [ExternalSecret](https://external-secrets.io/latest/api/externalsecret/) resources to be bound to the expected secrets store (according to the visibility you need) and to configure the target secret details
  - The following secret types of [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types) are currently supported:
    - `Opaque` (`opaque` in this module)
    - `kubernetes.io/dockerconfigjson` (`dockerconfigjson` in this module)

The current version of the module supports multitenants configuration by setting up "ESO as a service" (ref. https://cloud.redhat.com/blog/how-to-setup-external-secrets-operator-eso-as-a-service) for both authentication methods [More details below](#example-of-multitenancy-configuration-example-in-namespaced-externalsecrets-stores)

The following combinations of Kubernetes Secrets and Secrets Manager secrets are used with given [External-Secret type](https://external-secrets.io/latest/provider/ibm-secrets-manager/).

| es_kubernetes_secret_type[^1] | sm_secret_type[^2] | external_secret_type[^3] |
|-------------------------------|--------------------|--------------------------|
| dockerconfigjson              | arbitrary          | arbitrary                |
| dockerconfigjson              | iam_credentials    | iam_credentials          |
| dockerconfigjson              | username_password  | username_password        |
| opaque                        | arbitrary          | arbitrary                |
| opaque                        | iam_credentials    | iam_credentials          |
| opaque                        | username_password  | username_password        |
| opaque                        | kv                 | kv                       |
| tls                           | imported_cert      | imported_cert            |
| tls                           | public_cert        | public_cert              |
| tls                           | private_cert       | private_cert             |

[^1]: [es_kubernetes_secret_type](#input_es_kubernetes_secret_type): The Kubernetes Secrets type or format that ESO installs in the cluster.

[^2]: [sm_secret_type](#input_sm_secret_type): IBM Cloud Secrets Manager secret type that is used as source data by ESO.

[^3]: [external_secret_type](https://external-secrets.io/latest/provider/ibm-secrets-manager/#secret-types): The secret type that is used by ESO.

### Customise ESO deployment on specific cluster nodes

In order to customise the NodeSelector and the tolerations to make the External Secret Operator deployed on specific cluster nodes it is possible to configure the following input variable with the appropriate values:

```hcl
variable "eso_cluster_nodes_configuration" {
  description = "Configuration to use to customise ESO deployment on specific cluster nodes. Setting appropriate values will result in customising ESO helm release. Default value is null to keep ESO standard deployment."
  type = object({
    nodeSelector = object({
      label = string
      value = string
    })
    tolerations = object({
      key = string
      operator = string
      value = string
      effect = string
    })
  })
  default = null
}
```

For example:

```hcl
module "external_secrets_operator" {
  (...)
  eso_cluster_nodes_configuration = {
    nodeSelector = {
      label = "dedicated"
      value = "edge"
    }
    tolerations = {
      key = "dedicated"
      operator = "Equal"
      value = "edge"
      effect = "NoExecute"
    }
  }
  (...)
```

will make the External Secret Operator to run on clusters nodes labeled with `dedicated: edge`.

The resulting helm release configuration, according to the `terraform plan` output would be like

```bash
(...)
# module.external_secrets_operator.helm_release.external_secrets_operator[0] will be created
  + resource "helm_release" "external_secrets_operator" {
      + atomic                     = false
      + chart                      = "external-secrets"
      + cleanup_on_fail            = false
      + create_namespace           = false
      + dependency_update          = false
      + disable_crd_hooks          = false
      + disable_openapi_validation = false
      + disable_webhooks           = false
      + force_update               = false
      + id                         = (known after apply)
      + lint                       = false
      + manifest                   = (known after apply)
      + max_history                = 0
      + metadata                   = (known after apply)
      + name                       = "external-secrets"
      + namespace                  = "es-operator"
      + pass_credentials           = false
      + recreate_pods              = false
      + render_subchart_notes      = true
      + replace                    = false
      + repository                 = "https://charts.external-secrets.io"
      + reset_values               = false
      + reuse_values               = false
      + skip_crds                  = false
      + status                     = "deployed"
      + timeout                    = 300
      + values                     = [
          + <<-EOT
                installCRDs: true
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
            EOT,
          + <<-EOT
                nodeSelector: { dedicated: edge }
                tolerations:
                - key: dedicated
                  operator: Equal
                  value: edge
                  effect: NoExecute
                webhook:
                  nodeSelector: { dedicated: edge }
                  tolerations:
                  - key: dedicated
                    operator: Equal
                    value: edge
                    effect: NoExecute
                certController:
                  nodeSelector: { dedicated: edge }
                  tolerations:
                  - key: dedicated
                    operator: Equal
                    value: edge
                    effect: NoExecute
            EOT,
        ]
      + verify                     = false
      + version                    = "0.9.7"
      + wait                       = true
      + wait_for_jobs              = false
    }
(...)

```

Similarly exporting this environment variable

```bash
export TF_VAR_eso_cluster_nodes_configuration="{\"nodeSelector\": {\"label\": \"dedicated\", \"value\": \"transit\"}, \"tolerations\": {\"key\": \"dedicated\", \"operator\": \"Equal\", \"value\": \"transit\", \"effect\": \"NoExecute\"}}"
```

will make the External Secret Operator to run on clusters nodes labeled with `dedicated: transit`.

The default `null` value keeps the default ESO behaviour.

### Example of Multitenancy configuration example in namespaced externalsecrets stores

To configure a set of tenants to be configured in their proper namespace (to achieve tenant isolation) you need simply to follow these steps:

- deploy ESO in the cluster

```hcl
module "external_secrets_operator" {
  source               = "terraform-ibm-modules/external-secrets-operator/ibm"
  version              = <<the latest version of the module>>
  eso_namespace     = var.eso_namespace # namespace to deploy ESO
  service_endpoints = var.service_endpoints # use public or private endpoints for IAM and Secrets Manager
  eso_cluster_nodes_configuration = <<the eso configuration for specific cluster nodes selection if needed - read above>>
}
```

- create multiple `SecretStore`(s) in the proper namespaces

With `api_key` authentication mode

```hcl

module "eso_namespace_secretstore_1" {
  depends_on = [
    module.external_secrets_operator
  ]
  source                      = "../modules/eso-secretstore"
  eso_authentication          = "api_key"
  region                      = local.sm_region # SM region
  sstore_namespace            = var.es_kubernetes_namespaces[2] # namespace to create the secret store
  sstore_secrets_manager_guid = local.sm_guid # the guid of the secrets manager instance to use
  sstore_store_name           = "${var.es_kubernetes_namespaces[2]}-store" # store name
  # to pull the secrets from SM
  sstore_secret_apikey        = data.ibm_sm_iam_credentials_secret.secret_puller_secret.api_key # pragma: allowlist secret
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store" # helm release name suffix to use for the store
  sstore_secret_name          = "generic-cluster-api-key" #checkov:skip=CKV_SECRET_6
}

```

With `trusted_profile` authentication mode

```hcl
module "eso_namespace_secretstores" {
  depends_on = [
    module.external_secrets_operator
  ]
  source                      = "../modules/eso-secretstore"
  eso_authentication          = "trusted_profile"
  region                      = local.sm_region # SM region
  sstore_namespace            = kubernetes_namespace.examples[count.index].metadata[0].name # namespace to create the secret store
  sstore_secrets_manager_guid = local.sm_guid # the guid of the secrets manager instance to use
  sstore_store_name           = "${kubernetes_namespace.examples[count.index].metadata[0].name}-store" # store name
  sstore_trusted_profile_name = module.external_secrets_trusted_profiles[count.index].trusted_profile_name # trusted profile name to use into this secret store
  service_endpoints           = var.service_endpoints
  sstore_helm_rls_name        = "es-store-${count.index}" # helm release name suffix to use for the store
  sstore_secret_name          = "secretstore-api-key" #checkov:skip=CKV_SECRET_6
}

```

More details can be found in the examples linked below.

### More information links

For more information about IAM Trusted profiles and ESO Multitenancy configuration please refer to
- [IBM IAM Trusted profiles article](https://www.ibm.com/cloud/blog/announcements/use-trusted-profiles-to-simplify-user-and-access-management)
- [Setup of ESO as a Service from RedHat](https://cloud.redhat.com/blog/how-to-setup-external-secrets-operator-eso-as-a-service)
- [ESO Multitenancy configuration from ESO Docs](https://external-secrets.io/latest/guides/multi-tenancy/)

### _Important current architectural limitation of ESO deployment_

The current ESO version doesn't allow to customise the default IAM endpoint (https://iam.cloud.ibm.com) it uses when authenticating through apikey (`api_key` authentication) for both ClusterSecretStore and SecretStore APIs.

As a direct effect of this limitation, for an OCP cluster topology designed with three different subnet layers `edge` `private` and `transit`, where only `edge` one has access to the public network, `private` is for business workload and `transit` for private networking, an ESO deployment with `api_key` authentication configuration needs to be performed on the workers pool with access to the public network (`dedicated: edge` label in GE usual topology) to work fine. If the ESO deployment is performed on a workers pool without access to public network (i.e. to https://iam.cloud.ibm.com) the apikey authentication is expected to fail, unless ESO is enrolled into RedHat Service Mesh (this module allows to add the expected resources annotations but the Mesh gateways configuration is out of the scope of the module) or a different networking solution is implemented.


### Pod Reloader

When secrets are updated, depending on you configuration pods may need to be restarted to pick up the new secrets. To do this you can use the [Stakater Reloader](https://github.com/stakater/Reloader).
By default, the module deploys this to watch for changes in secrets and configmaps and trigger a rolling update of the related pods.
To have Reloader watch a secret or configMap add the annotation `reloader.stakater.com/auto: "true"` to the secret or configMap, the same annotation can be added to deployments to have them restarted when the secret or configMap changes.
When using the [eso-external-secret](modules/eso-external-secret) submodule, use the `reloader_watching` variable to have the annotation added to the secret.

This can be further configured as needed, for more details see https://github.com/stakater/Reloader By default is watches all namespaces.
If you do not need it please set `reloader_deployed = false` in the module call.

### Troubleshooting

In the case of problems with secrets synchronization a good start point to the investigation is to list the externalsecrets resources in the cluster:

```bash
oc get externalsecrets -A
NAMESPACE       NAME                                                  AGE   STATUS   CAPABILITIES   READY
apikeynspace3   secretstore.external-secrets.io/apikeynspace3-store   32m   Valid    ReadOnly       True
apikeynspace4   secretstore.external-secrets.io/apikeynspace4-store   32m   Valid    ReadOnly       True
tpnspace1       secretstore.external-secrets.io/tpnspace1-store       32m   Valid    ReadOnly       True
tpnspace2       secretstore.external-secrets.io/tpnspace2-store       32m   Valid    ReadOnly       True

NAMESPACE   NAME                                                   AGE   STATUS   CAPABILITIES   READY
            clustersecretstore.external-secrets.io/cluster-store   32m   Valid    ReadOnly       True

NAMESPACE       NAME                                                                     STORE                 REFRESH INTERVAL   STATUS              READY
apikeynspace1   externalsecret.external-secrets.io/dockerconfigjson-uc                   cluster-store         1m                 SecretSyncedError   False
apikeynspace2   externalsecret.external-secrets.io/cloudant-opaque-arb                   cluster-store         5m                 SecretSyncedError   False
apikeynspace3   externalsecret.external-secrets.io/dockerconfigjson-arb                  apikeynspace3-store   1h                 SecretSyncedError   False
apikeynspace4   externalsecret.external-secrets.io/dockerconfigjson-iam                  apikeynspace4-store   1h                 SecretSyncedError   False
tpnspace1       externalsecret.external-secrets.io/geretain-tesoall-arbitrary-arb-tp-0   tpnspace1-store       5m                 SecretSynced        True
tpnspace2       externalsecret.external-secrets.io/geretain-tesoall-arbitrary-arb-tp-1   tpnspace2-store       5m                 SecretSynced        True
```

In the example above some of the externalsecrets are experiencing secrets synchronization errors.
By describing them you should be able to identify the error:

```bash
oc describe externalsecret dockerconfigjson-uc -n apikeynspace1
Name:         dockerconfigjson-uc
Namespace:    apikeynspace1
Labels:       app=raw
              app.kubernetes.io/managed-by=Helm
              chart=raw-v0.2.5
              heritage=Helm
              release=apikeynspace1-es-docker-uc
Annotations:  meta.helm.sh/release-name: apikeynspace1-es-docker-uc
              meta.helm.sh/release-namespace: apikeynspace1
API Version:  external-secrets.io/v1
Kind:         ExternalSecret
Metadata:
  (...)
Status:
  Conditions:
    Last Transition Time:  2023-06-27T15:18:31Z
    Message:               could not get secret data from provider
    Reason:                SecretSyncedError
    Status:                False
    Type:                  Ready
  Refresh Time:            <nil>
Events:
  Type     Reason        Age                  From              Message
  ----     ------        ----                 ----              -------
  (...)
  Warning  UpdateFailed  119s (x13 over 28m)  external-secrets  An error occurred while performing the 'authenticate' step: Post "https://iam.cloud.ibm.com/identity/token": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

In the output above there is a problem with reaching IAM endpoint (verify that the pods where ESO is running are able to reach that endpoint)

### _Important note_

If you taint or destroy or simply make a change that needs the helm_release resource of the ESO operator to be deleted and recreated, this would make terraform to destroy the operator itself, including all the CRDs, which would destroy all the secrets synched through ESO, even if the helm_release resource of these CRDs aren't directly touched and terraform wouldn't be able to identify such a change.
So in the case you plan to make changes to the operator helm_release once deployed, run preliminary a `terraform plan` to be sure that the release isn't destroyed and recreated.

### Examples of the secrets format and layout

<details><summary>dockerconfigjson from arbitrary or iam_credentials</summary>

Secret Body >

```
apiVersion: v1
kind: Secret
metadata:
  name: dockerconfigjson-iam
  namespace: test-ns
data:
  .dockerconfigjson: [BASE64ENCODED]
type: kubernetes.io/dockerconfigjson
```

Base64 Decoded `.dockerconfigson` >

```
{
  "auths": {
    "us.icr.io": {
      "username": "iamapikey",
      "password": "APIKEYVALUE", # pragma: allowlist secret
      "email": "terraform@ibm.com"
    }
  }
}
```

</details>

<details><summary>dockerconfigjson from username_password</summary>

Secret Body >
```
apiVersion: v1
kind: Secret
metadata:
  name: dockerconfigjson-uc
  namespace: test-ns
data:
  .dockerconfigjson: [BASE64ENCODED]
type: kubernetes.io/dockerconfigjson
```

Base64 Decoded `.dockerconfigson` >

```
{
  "auths": {
    "xx.artifactory.xyz-devops.com": {
      "username": "artifactoryuser@org.com",
      "password": "APIKEYVALUE" # pragma: allowlist secret
    }
  }
}
```

</details>

<details><summary>opaque from arbitrary or iam_credentials</summary>

Secret Body >
```
apiVersion: v1
kind: Secret
metadata:
  name: opaque-arb
  namespace: test-ns
type: Opaque
data:
  apikey: APIKEYVALUE # pragma: allowlist secret

```

</details>

<details><summary>opaque from username_password</summary>

Secret Body >
```
apiVersion: v1
kind: Secret
metadata:
  name: opaque-uc
  namespace: test-ns
type: Opaque
data:
  username: test-user
  password: PASSWORDVALUE # pragma: allowlist secret

```

</details>

## Usage

```hcl
# Replace "master" with a GIT release version to lock into a specific release
module "external_secrets_operator" {
  source        = "git::https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator.git?ref=master"
  eso_namespace = var.eso_namespace
}
```

## Required IAM access policies
You need the following permissions to run this module.

- Account Management
    - IAM Services
        - **Secrets Manager** service
            - `Administrator` platform access
            - `Manager` service access
        - **Kubernetes** service
            - `Administrator` platform access
            - `Manager` service access

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0, <4.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.16.1, < 3.0.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eso_namespace"></a> [eso\_namespace](#module\_eso\_namespace) | terraform-ibm-modules/namespace/ibm | 1.0.3 |

### Resources

| Name | Type |
|------|------|
| [helm_release.external_secrets_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.pod_reloader](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.existing_eso_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/namespace) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eso_chart_location"></a> [eso\_chart\_location](#input\_eso\_chart\_location) | The location of the External Secrets Operator Helm chart. | `string` | `"https://charts.external-secrets.io"` | no |
| <a name="input_eso_chart_version"></a> [eso\_chart\_version](#input\_eso\_chart\_version) | The version of the External Secrets Operator Helm chart. Ensure that the chart version is compatible with the image version specified in eso\_image\_version. | `string` | `"0.20.2"` | no |
| <a name="input_eso_cluster_nodes_configuration"></a> [eso\_cluster\_nodes\_configuration](#input\_eso\_cluster\_nodes\_configuration) | Configuration to use to customise ESO deployment on specific cluster nodes. Setting appropriate values will result in customising ESO helm release. Default value is null to keep ESO standard deployment. | <pre>object({<br/>    nodeSelector = object({<br/>      label = string<br/>      value = string<br/>    })<br/>    tolerations = object({<br/>      key      = string<br/>      operator = string<br/>      value    = string<br/>      effect   = string<br/>    })<br/>  })</pre> | `null` | no |
| <a name="input_eso_enroll_in_servicemesh"></a> [eso\_enroll\_in\_servicemesh](#input\_eso\_enroll\_in\_servicemesh) | Flag to enroll ESO into istio servicemesh | `bool` | `false` | no |
| <a name="input_eso_image"></a> [eso\_image](#input\_eso\_image) | The External Secrets Operator image in the format of `[registry-url]/[namespace]/[image]`. | `string` | `"ghcr.io/external-secrets/external-secrets"` | no |
| <a name="input_eso_image_version"></a> [eso\_image\_version](#input\_eso\_image\_version) | The version or digest for the external secrets image to deploy. If changing the value, ensure it is compatible with the chart version set in eso\_chart\_version. | `string` | `"v0.20.3-ubi@sha256:402a0d76880a095d7eec97e81a49a93096d256cf29941e842b22f8def7362c75"` | no |
| <a name="input_eso_namespace"></a> [eso\_namespace](#input\_eso\_namespace) | Namespace to create and be used to install ESO components including helm releases. | `string` | `null` | no |
| <a name="input_eso_pod_configuration"></a> [eso\_pod\_configuration](#input\_eso\_pod\_configuration) | Configuration to use to customise ESO deployment on specific pods. Setting appropriate values will result in customising ESO helm release. Default value is {} to keep ESO standard deployment. Ignore the key if not required. | <pre>object({<br/>    annotations = optional(object({<br/>      # The annotations for external secret controller pods.<br/>      external_secrets = optional(map(string), {})<br/>      # The annotations for external secret cert controller pods.<br/>      external_secrets_cert_controller = optional(map(string), {})<br/>      # The annotations for external secret controller pods.<br/>      external_secrets_webhook = optional(map(string), {})<br/>    }), {})<br/><br/>    labels = optional(object({<br/>      # The labels for external secret controller pods.<br/>      external_secrets = optional(map(string), {})<br/>      # The labels for external secret cert controller pods.<br/>      external_secrets_cert_controller = optional(map(string), {})<br/>      # The labels for external secret controller pods.<br/>      external_secrets_webhook = optional(map(string), {})<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_existing_eso_namespace"></a> [existing\_eso\_namespace](#input\_existing\_eso\_namespace) | Existing Namespace to be used to install ESO components including helm releases. | `string` | `null` | no |
| <a name="input_reloader_chart_location"></a> [reloader\_chart\_location](#input\_reloader\_chart\_location) | The location of the Reloader Helm chart. | `string` | `"https://stakater.github.io/stakater-charts"` | no |
| <a name="input_reloader_chart_version"></a> [reloader\_chart\_version](#input\_reloader\_chart\_version) | The version of the Reloader Helm chart. Ensure that the chart version is compatible with the image version specified in reloader\_image\_version. | `string` | `"2.2.3"` | no |
| <a name="input_reloader_custom_values"></a> [reloader\_custom\_values](#input\_reloader\_custom\_values) | String containing custom values to be used for reloader helm chart. See https://github.com/stakater/Reloader/blob/master/deployments/kubernetes/chart/reloader/values.yaml | `string` | `null` | no |
| <a name="input_reloader_deployed"></a> [reloader\_deployed](#input\_reloader\_deployed) | Whether to deploy reloader or not https://github.com/stakater/Reloader | `bool` | `true` | no |
| <a name="input_reloader_ignore_configmaps"></a> [reloader\_ignore\_configmaps](#input\_reloader\_ignore\_configmaps) | Whether to ignore configmap changes or not | `bool` | `false` | no |
| <a name="input_reloader_ignore_secrets"></a> [reloader\_ignore\_secrets](#input\_reloader\_ignore\_secrets) | Whether to ignore secret changes or not | `bool` | `false` | no |
| <a name="input_reloader_image"></a> [reloader\_image](#input\_reloader\_image) | The reloader image repository in the format of `[registry-url]/[namespace]/[image]`. | `string` | `"ghcr.io/stakater/reloader"` | no |
| <a name="input_reloader_image_version"></a> [reloader\_image\_version](#input\_reloader\_image\_version) | The version or digest for the reloader image to deploy. If changing the value, ensure it is compatible with the chart version set in reloader\_chart\_version. | `string` | `"v1.4.8-ubi@sha256:d87801fae5424f347d34b776ba25ea0c1ba80a8b50ba91ece0777206a47d91d3"` | no |
| <a name="input_reloader_is_argo_rollouts"></a> [reloader\_is\_argo\_rollouts](#input\_reloader\_is\_argo\_rollouts) | Enable Argo Rollouts | `bool` | `false` | no |
| <a name="input_reloader_is_openshift"></a> [reloader\_is\_openshift](#input\_reloader\_is\_openshift) | Enable OpenShift DeploymentConfigs | `bool` | `true` | no |
| <a name="input_reloader_log_format"></a> [reloader\_log\_format](#input\_reloader\_log\_format) | The log format to use for reloader. Possible values are `json` or `text`. Default value is `json` | `string` | `"text"` | no |
| <a name="input_reloader_namespaces_selector"></a> [reloader\_namespaces\_selector](#input\_reloader\_namespaces\_selector) | List of comma separated label selectors, if multiple are provided they are combined with the AND operator | `string` | `null` | no |
| <a name="input_reloader_namespaces_to_ignore"></a> [reloader\_namespaces\_to\_ignore](#input\_reloader\_namespaces\_to\_ignore) | List of comma separated namespaces to ignore for reloader. If multiple are provided they are combined with the AND operator | `string` | `null` | no |
| <a name="input_reloader_pod_monitor_metrics"></a> [reloader\_pod\_monitor\_metrics](#input\_reloader\_pod\_monitor\_metrics) | Enable to scrape Reloader's Prometheus metrics | `bool` | `false` | no |
| <a name="input_reloader_reload_on_create"></a> [reloader\_reload\_on\_create](#input\_reloader\_reload\_on\_create) | Enable reload on create events | `bool` | `true` | no |
| <a name="input_reloader_reload_strategy"></a> [reloader\_reload\_strategy](#input\_reloader\_reload\_strategy) | The reload strategy to use for reloader. Possible values are `env-vars` or `annotations`. Default value is `annotations` | `string` | `"annotations"` | no |
| <a name="input_reloader_resource_label_selector"></a> [reloader\_resource\_label\_selector](#input\_reloader\_resource\_label\_selector) | List of comma separated label selectors, if multiple are provided they are combined with the AND operator | `string` | `null` | no |
| <a name="input_reloader_resources_to_ignore"></a> [reloader\_resources\_to\_ignore](#input\_reloader\_resources\_to\_ignore) | List of comma separated resources to ignore for reloader. If multiple are provided they are combined with the AND operator | `string` | `null` | no |
| <a name="input_reloader_sync_after_restart"></a> [reloader\_sync\_after\_restart](#input\_reloader\_sync\_after\_restart) | Enable sync after Reloader restarts for Add events, works only when reloadOnCreate is true | `bool` | `true` | no |

### Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- Leave this section as is so that your module has a link to local development environment set up steps for contributors to follow -->
## Contributing

You can report issues and request features for this module in GitHub issues in the module repo. See [Report an issue or request a feature](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md).

To set up your local development environment, see [Local development setup](https://terraform-ibm-modules.github.io/documentation/#/local-dev-setup) in the project documentation.
