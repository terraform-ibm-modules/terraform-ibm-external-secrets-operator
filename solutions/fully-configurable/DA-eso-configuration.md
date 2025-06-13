# Configuring External Secrets Operator stores

In the Architecture configuration it is possible to configure the set of [Cluster Secrets Stores](https://external-secrets.io/latest/api/clustersecretstore/) and [Secrets Stores](https://external-secrets.io/latest/api/clustersecretstore/) to deploy on the cluster after the External Secrets Operator deployment and that are responsible to handle the integration of the operator components with the IBM Cloud Secrets Manager instance.
The configuration of these stores is performed through the complex object `eso_secretsstores_configuration` and by specifying this input parameter when configuring the deployable architecture.

The input variable `eso_secretsstores_configuration` is a map with two keys, `cluster_secrets_stores` and `secrets_stores`, that respectively collect the list of objects to define the cluster secrets stores and secrets stores. Each object in the two map's elements represent a secrets store. Each store's key is used also as name of the store itself. Each store has the following attributes to define its configuration:
  - `namespace` is the namespace where the store is to be created, and `create_namespace` can be used to control if the namespace is to be created or it is already available on the cluster.
  - `serviceid_name` and `serviceid_description` provide the details to create the ServiceID to be entitled to read the secrets from Secrets Manager. As alternative, if already available, it is possible to specify `existing_serviceid_id` (no ServiceID is created in this case). The ServiceID (newly created or existing) will be provided with the IAM the policies to read the secrets for each of the Secrets Groups associated with the store.
  - `account_secrets_group_name` and `account_secrets_group_description` provide the details to create the Secrets Group (named Account Secrets Group in the context of ESO) where to create the secret to store the API key (called account API key starting from now) configured in the cluster to pull the secrets from Secrets Manager (and owned by the ServiceID defined through `serviceid_name` and `serviceid_description`). As alternative is possible to provide the ID of an already existing Account ServiceID through `existing_account_secrets_group_id`. In this case no Account ServiceID is created.
  - `service_secrets_groups_list` is the list of Secrets Groups to create for the store where to create the secrets to be managed by the store. Each element of the list has two fields `name` and `description` to configure the Secret Group.
  - `existing_service_secrets_group_id_list` is the list of already existing Secrets Group where to create the secrets to be managed by the store. This list will be merged to the list of the ones created through the `service_secrets_groups_list` and the final list will be used to create the policies to allow the ServiceID owner of the account API key to read the secrets in these Secrets Groups
  - `trusted_profile_name` and `trusted_profile_description` provide the details to authenticate pull the secrets from Secrets Manager through trusted profile authentication as alternative to API key one.
  - the logic to authenticate on Secrets Manager for the store to pull secrets is the following:
     - if a trusted profile name is provided, the trusted profile is created and the related authentication is used to pull secrets from Secrets Manager for the store. If no trusted profile is provided
     - if an existing ServiceID is provided, it will be used to pull secrets from Secrets Manager (and will be provided with the entitlement to read secrets for all the Service Secrets Groups)
     - if an existing ServiceID isn't provided, the ServiceID created through `serviceid_name` and `serviceid_description` will be used

Below an example that sets this input variable:

```
{
  cluster_secrets_stores = {
    "cluster-secrets-store-1" = {
      namespace = "eso-namespace-cs1"
      create_namespace = true
      existing_serviceid_id = null
      serviceid_name = "esoda-test-cluster-secrets-store-1-serviceid"
      serviceid_description = "esoda-test-cluster-secrets-store-1-serviceid description"
      existing_account_secrets_group_id = ""
      account_secrets_group_name = "esoda-test-cs-account-secrets-group-1"
      account_secrets_group_description = "esoda-test-cs-account-secrets-group-1 description"
      trusted_profile_name = ""
      trusted_profile_description = null
      existing_service_secrets_group_id_list = []
      service_secrets_groups_list = [{
          name = "esoda-test-cs-service1-secrets-group"
          description = "Secrets group for secrets used by the ESO"
      },{
          name = "esoda-test-cs-service2-secrets-group"
          description = "Secrets group 2 for secrets used by the ESO"
      }]
    },
    "cluster-secrets-store-2" = {
      namespace = "eso-namespace-cs2"
      create_namespace = true
      existing_serviceid_id = null
      serviceid_name = ""
      serviceid_description = ""
      existing_account_secrets_group_id = "23cc32a3-d29e-688b-abe2-d7f7129f73f3"
      account_secrets_group_name = "esoda-test-cs-account-secrets-group-2"
      account_secrets_group_description = "esoda-test-cs-account-secrets-group-2 description"
      trusted_profile_name = null
      trusted_profile_description = null
      existing_service_secrets_group_id_list = []
      service_secrets_groups_list = [{
          name = "esoda-test-cs-service3-secrets-group"
          description = "Secrets group 3 for secrets used by the ESO"
      },{
          name = "esoda-test-cs-service4-secrets-group"
          description = "Secrets group 4 for secrets used by the ESO"
      }]
    },
    "cluster-secrets-store-3" = {
      namespace = "eso-namespace-cs3"
      create_namespace = true
      existing_serviceid_id = null
      serviceid_name = ""
      serviceid_description = ""
      existing_account_secrets_group_id = ""
      account_secrets_group_name = "esoda-test-cs-account-secrets-group-2"
      account_secrets_group_description = "esoda-test-cs-account-secrets-group-2 description"
      trusted_profile_name = "cs3-trustedprofile"
      trusted_profile_description = "Trusted profile to authenticate cs3"
      existing_service_secrets_group_id_list = []
      service_secrets_groups_list = [{
          name = "esoda-test-cs-service5-secrets-group"
          description = "Secrets group 5 for secrets used by the ESO"
      },{
          name = "esoda-test-cs-service6-secrets-group"
          description = "Secrets group 6 for secrets used by the ESO"
      }]
    }
  }
  secrets_stores = {
    "secrets-store-1" = {
      namespace = "eso-namespace-ss1"
      create_namespace = true
      existing_serviceid_id = "ServiceId-0ec46d95-c28d-4768-a912-5fcf73d4959e"
      serviceid_name = ""
      serviceid_description = ""
      existing_account_secrets_group_id = ""
      account_secrets_group_name = "esoda-test-ss-account-secrets-group-1"
      account_secrets_group_description = "esoda-test-ss-account-secrets-group-1 description"
      trusted_profile_name = ""
      trusted_profile_description = null
      existing_service_secrets_group_id_list = []
      service_secrets_groups_list = [{
          name = "esoda-test-ss-service1-secrets-group"
          description = "Secrets group 1 for secrets used by the ESO"
      },{
          name = "esoda-test-ss-service2-secrets-group"
          description = "Secrets group 2 for secrets used by the ESO"
      }]
    },
    "secrets-store-2" = {
      namespace = "eso-namespace-ss2"
      create_namespace = true
      existing_serviceid_id = null
      serviceid_name = "esoda-test-secrets-store-2-serviceid"
      serviceid_description = "esoda-test-secrets-store-2-serviceid description"
      existing_account_secrets_group_id = ""
      account_secrets_group_name = "esoda-test-ss-account-secrets-group-2"
      account_secrets_group_description = "esoda-test-ss-account-secrets-group-2 description"
      trusted_profile_name = null
      trusted_profile_description = null
      existing_service_secrets_group_id_list = []
      service_secrets_groups_list = [{
          name = "esoda-test-ss-service3-secrets-group"
          description = "Secrets group 3 for secrets used by the ESO"
      },{
          name = "esoda-test-ss-service4-secrets-group"
          description = "Secrets group 4 for secrets used by the ESO"
      }]
    }
  }
}
```
