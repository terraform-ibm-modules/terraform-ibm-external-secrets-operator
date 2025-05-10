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