# Terraform IBM External Secrets Operator

This architecture allows to deploy [External Secrets Operator](https://external-secrets.io/latest/) (also known as ESO) on an existing IBM Cloud OpenShift Cluster

External Secrets Operator synchronizes secrets in the Kubernetes cluster with secrets that are mapped in [Secrets Manager](https://cloud.ibm.com/docs/secrets-manager).

The architecture provides the following features:
- Install and configure External Secrets Operator (ESO).
- Customise External Secret Operator deployment on specific cluster workers by configuration approriate NodeSelector and Tolerations in the ESO helm release [More details below](#customise-eso-deployment-on-specific-cluster-nodes)
- Deploy and configure [ClusterSecretStore](https://external-secrets.io/latest/api/clustersecretstore/) resources for cluster scope secrets store
- Deploy and configure [SecretStore](https://external-secrets.io/latest/api/secretstore/) resources for namespace scope secrets store
- Leverage on two authentication methods to be configured on the single stores instances:
  - IAM apikey standard authentication
  - IAM Trusted profile

The current version of the architecture supports multitenants configuration by setting up "ESO as a service" (ref. https://cloud.redhat.com/blog/how-to-setup-external-secrets-operator-eso-as-a-service) for both authentication methods
[More details](https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator#example-of-multitenancy-configuration-example-in-namespaced-externalsecrets-stores)

### Pod Reloader

The architecture allows also to deploy optionally Stakater Reloader](https://github.com/stakater/Reloader): when secrets are updated, depending on you configuration pods may need to be restarted to pick up the new secrets. To do this you can use it.
By default, the module deploys this to watch for changes in secrets and configmaps and trigger a rolling update of the related pods.
To have Reloader watch a secret or configMap add the annotation `reloader.stakater.com/auto: "true"` to the secret or configMap, the same annotation can be added to deployments to have them restarted when the secret or configMap changes.

This can be further configured as needed, for more details see https://github.com/stakater/Reloader By default it watches all namespaces.
If you do not need it please set `reloader_deployed = false` in the input variable value.

### Output content and Secrets configuration

This architecture doesn't provide support for configuring the Secrets and the ESO external-secrets structures needed to synchronize the secret with Secrets Manager.
However its output provides, for each Cluster Secrets Store and Secrets Store configured in input, the IDs for the ServiceIDs, for the Account and Service Secrets Groups and so on: these output structures can be easily used in a terraform template to configure and deploy the secrets on the cluster.
The code below is an example of generating a username/password secret on Secrets Manager to deploy a dockerjson cluster secret for each Cluster Secrets Store:

```
##################################################################
# creation of generic username/password secret
# (for example to store artifactory username and API key)
##################################################################

locals {
  # secret value for sm_userpass_secret
  userpass_apikey = sensitive("password-payload-example")
}

# Create username_password secret and store in secret manager
module "sm_userpass_secret" {
  for_each = local.cluster_secrets_stores_account_secrets_groups
  source               = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version              = "1.7.0"
  region               = local.sm_region
  secrets_manager_guid = local.sm_guid
  secret_group_id      = each.value.secrets_group.secret_group_id
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_name             = "${each.key}-usernamepassword-secret"              # checkov:skip=CKV_SECRET_6
  secret_description      = "example secret for ${each.value.name}" #tfsec:ignore:general-secrets-no-plaintext-exposure # checkov:skip=CKV_SECRET_6
  secret_payload_password = local.userpass_apikey # pragma: allowlist secret
  secret_type             = "username_password" #checkov:skip=CKV_SECRET_6
  #tfsec:ignore:general-secrets-no-plaintext-exposure
  secret_username               = "artifactory-user" # checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_auto_rotation          = false
  secret_auto_rotation_interval = 0
  secret_auto_rotation_unit     = null
  providers = {
    ibm = ibm.ibm-sm
  }
}

##################################################################
# ESO externalsecrets with cluster scope and apikey authentication
##################################################################

# ESO externalsecret with cluster scope creating a dockerconfigjson type secret
module "external_secret_usr_pass" {
  for_each = local.cluster_secrets_store_account_serviceid_apikey_secrets
  depends_on                = [module.eso_clustersecretsstore]
  source                    = "../../modules/eso-external-secret"
  es_kubernetes_secret_type = "dockerconfigjson"  #checkov:skip=CKV_SECRET_6
  sm_secret_type            = "username_password" #checkov:skip=CKV_SECRET_6
  sm_secret_id              = each.value.secrets_manager_secret.secret_id
  es_kubernetes_namespace   = var.eso_secretsstores_configuration.cluster_secrets_stores[each.key].namespace
  eso_store_name            = each.key
  es_container_registry     = "example-registry-local.artifactory.com"
  es_kubernetes_secret_name = "dockerconfigjson-uc" #checkov:skip=CKV_SECRET_6
  es_helm_rls_name          = "es-docker-uc"
}

output "sm_userpass_secret" {
  value = module.sm_userpass_secret
}
```
