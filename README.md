## External Secrets Operator module

[![Certified](<https://img.shields.io/badge/Status-Certified%20(GA)-brightgreen?style=plastic>)](https://github.ibm.com/GoldenEye/documentation/blob/master/status.md)
[![CI](https://img.shields.io/badge/CI-Toolchain%20Tekton%20Pipeline-3662FF?logo=ibm)](https://cloud.ibm.com/devops/toolchains/c3916535-165a-4275-9b1f-c58575839951?env_id=ibm:yp:us-south)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![latest release](https://shields-server.m03l6u0cqkx.eu-de.codeengine.appdomain.cloud/github/v/release/GoldenEye/external-secrets-operator-module?logo=GitHub)](https://github.ibm.com/GoldenEye/external-secrets-operator-module/releases/latest)

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
* [Contributing](#contributing)
<!-- END OVERVIEW HOOK -->

## Compliance and security

NIST controls do not apply to this module.

<!-- Match this heading to the name of the root level module (the repo name) -->
## external-secrets-operator-module

External Secrets Operator synchronizes secrets in the Kubernetes cluster with secrets that are mapped in [Secrets Manager](https://cloud.ibm.com/docs/secrets-manager).

The module provides the following features:
- Install and configure External Secrets Operator (ESO).
- Customise External Secret Operator deployment on specific cluster workers by configuration approriate NodeSelector and Tolerations in the ESO helm release [More details below](#customise-eso-deployment-on-specific-cluster-nodes)

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
      + chart      = "oci://icr.io/goldeneye_images/external-secrets"
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
  source            = "git::https://github.ibm.com/GoldenEye/external-secrets-operator-module.git?ref=<the version you need>"
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
  source                      = "git::https://github.ibm.com/GoldenEye/external-secrets-operator-module.git//modules/eso-secretstore?ref=master"
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
  source                      = "git::https://github.ibm.com/GoldenEye/external-secrets-operator-module.git//modules/eso-secretstore?ref=master"
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

### _Important current limitation of ESO deployment_

The current ESO version doesn't allow to customise the default IAM endpoint (https://iam.cloud.ibm.com) it uses when authenticating through apikey (`api_key` authentication) for both ClusterSecretStore and SecretStore APIs.

As a direct effect of this limitation, for a standard OCP cluster topology as defined by GoldenEye design (3 workers zones `edge` `private` and `transit`), an ESO deployment with `api_key` authentication configuration needs to be performed on the workers pool with access to the public network (`dedicated: edge` label in GE usual topology) to work fine. If the ESO deployment is performed on a workers pool without access to public network (i.e. to https://iam.cloud.ibm.com) the apikey authentication is expected to fail.


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
API Version:  external-secrets.io/v1beta1
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

In the output above there is a problem with reaching IAM endpoint (as the ESO pods were deployed on private network and it was trying to reach IAM on public endpoint)

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
    "xx.artifactory.swg-devops.com": {
      "username": "artifactoryuser@ibm.com",
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


NIST controls do not apply to this module.

## Usage

```hcl
# Replace "master" with a GIT release version to lock into a specific release
module "es_kubernetes_secret" {
  source                     = "git::https://github.ibm.com/GoldenEye/external-secrets-operator-module.git//modules/eso-external-secret?ref=master"
  es_kubernetes_secret_type = "dockerconfigjson"
  sm_secret_type = "iam_credentials"
  sm_secret_id = module.docker_config.serviceid_apikey_secret_id
  eso_setup = true
  es_kubernetes_namespaces = var.es_kubernetes_namespaces
  es_docker_email = "terraform@ibm.com"
  eso_generic_secret_apikey = data.ibm_secrets_manager_secret.secret_puller_secret.api_key # pragma: allowlist secret
  secrets_manager_guid = module.secrets_manager_iam_configuration.secrets_manager_guid
  region = "us-south"
  es_kubernetes_secret_name = "dockerconfigjson-iam"
  depends_on = [
    kubernetes_namespace.cluster_namespaces
  ]
  es_kubernetes_secret_data_key = "apiKey"
  es_helm_rls_name = "es-docker-iam"
}
```

<!-- BEGIN EXAMPLES HOOK -->
## Examples

- [ Basic Example](examples/basic)
- [ Example that uses trusted profiles (container authentication)](examples/trusted-profiles-authentication)
<!-- END EXAMPLES HOOK -->

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11.0, < 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.16.1, < 3.0.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eso_namespace"></a> [eso\_namespace](#module\_eso\_namespace) | terraform-ibm-modules/namespace/ibm | 1.0.2 |

### Resources

| Name | Type |
|------|------|
| [helm_release.external_secrets_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.pod_reloader](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.existing_eso_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/namespace) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eso_cluster_nodes_configuration"></a> [eso\_cluster\_nodes\_configuration](#input\_eso\_cluster\_nodes\_configuration) | Configuration to use to customise ESO deployment on specific cluster nodes. Setting appropriate values will result in customising ESO helm release. Default value is null to keep ESO standard deployment. | <pre>object({<br/>    nodeSelector = object({<br/>      label = string<br/>      value = string<br/>    })<br/>    tolerations = object({<br/>      key      = string<br/>      operator = string<br/>      value    = string<br/>      effect   = string<br/>    })<br/>  })</pre> | `null` | no |
| <a name="input_eso_enroll_in_servicemesh"></a> [eso\_enroll\_in\_servicemesh](#input\_eso\_enroll\_in\_servicemesh) | Flag to enroll ESO into istio servicemesh | `bool` | `false` | no |
| <a name="input_eso_image_repo"></a> [eso\_image\_repo](#input\_eso\_image\_repo) | The repository for the External Secrets Operator image. Default is `ghcr.io/external-secrets/external-secrets`. | `string` | `"ghcr.io/external-secrets/external-secrets"` | no |
| <a name="input_eso_image_tag_digest"></a> [eso\_image\_tag\_digest](#input\_eso\_image\_tag\_digest) | The tag or digest for the External Secrets Operator image. Provide a digest in the format `sha256:xxxxx...` for immutability or leave it as a tag version. | `string` | `"v0.11.0-ubi@sha256:b5f685b86cf684020e863c6c2ed91e8a79cad68260d7149ddee073ece2573d6f"` | no |
| <a name="input_eso_namespace"></a> [eso\_namespace](#input\_eso\_namespace) | Namespace to create and be used to install ESO components including helm releases. If eso\_store\_scope == cluster, this will also be used to deploy ClusterSecretStore/cluster\_store in it | `string` | `null` | no |
| <a name="input_eso_pod_configuration"></a> [eso\_pod\_configuration](#input\_eso\_pod\_configuration) | Configuration to use to customise ESO deployment on specific pods. Setting appropriate values will result in customising ESO helm release. Default value is {} to keep ESO standard deployment. Ignore the key if not required. | <pre>object({<br/>    annotations = optional(object({<br/>      # The annotations for external secret controller pods.<br/>      external_secrets = optional(map(string), {})<br/>      # The annotations for external secret cert controller pods.<br/>      external_secrets_cert_controller = optional(map(string), {})<br/>      # The annotations for external secret controller pods.<br/>      external_secrets_webhook = optional(map(string), {})<br/>    }), {})<br/><br/>    labels = optional(object({<br/>      # The labels for external secret controller pods.<br/>      external_secrets = optional(map(string), {})<br/>      # The labels for external secret cert controller pods.<br/>      external_secrets_cert_controller = optional(map(string), {})<br/>      # The labels for external secret controller pods.<br/>      external_secrets_webhook = optional(map(string), {})<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_existing_eso_namespace"></a> [existing\_eso\_namespace](#input\_existing\_eso\_namespace) | Existing Namespace to be used to install ESO components including helm releases. If eso\_store\_scope == cluster, this will also be used to deploy ClusterSecretStore/cluster\_store in it | `string` | `null` | no |
| <a name="input_reloader_custom_values"></a> [reloader\_custom\_values](#input\_reloader\_custom\_values) | String containing custom values to be used for reloader helm chart. See https://github.com/stakater/Reloader/blob/master/deployments/kubernetes/chart/reloader/values.yaml | `string` | `null` | no |
| <a name="input_reloader_deployed"></a> [reloader\_deployed](#input\_reloader\_deployed) | Whether to deploy reloader or not https://github.com/stakater/Reloader | `bool` | `true` | no |
| <a name="input_reloader_ignore_configmaps"></a> [reloader\_ignore\_configmaps](#input\_reloader\_ignore\_configmaps) | Whether to ignore configmap changes or not | `bool` | `false` | no |
| <a name="input_reloader_ignore_secrets"></a> [reloader\_ignore\_secrets](#input\_reloader\_ignore\_secrets) | Whether to ignore secret changes or not | `bool` | `false` | no |
| <a name="input_reloader_image_repo"></a> [reloader\_image\_repo](#input\_reloader\_image\_repo) | The repository for the Stakater Reloader image. Default is `ghcr.io/stakater/reloader`. | `string` | `"ghcr.io/stakater/reloader"` | no |
| <a name="input_reloader_image_tag_digest"></a> [reloader\_image\_tag\_digest](#input\_reloader\_image\_tag\_digest) | The tag or digest for the Stakater Reloader image. Provide a digest in the format `sha256:xxxxx...` for immutability or leave it as a tag version. | `string` | `"v1.2.0-ubi@sha256:375736e6690986559022cae504bebd8dfe14a37ac0305176f8826362c29732d6f"` | no |
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
