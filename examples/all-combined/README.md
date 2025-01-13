# Example to deploy the External Secret Operator and to create a different set of resources in terms of secrets, secret groups, stores and auth configurations

This end-to-end example performs the following actions
- Loads an existing resource group or creates a new one
- Provisions a standard GoldenEye OCP infrastructure with VPC, COS instance and an OpenShift cluster
- Configures an hybrid ESO configuration with a set of different stores to cover use-cases
  - a ClusterSecretStore with API key authentication
  - a ClusterSecretStore with Trusted profile authentication
  - two namespaced SecretStore with API key authentication
  - two namespaced SecretStore with Trusted Profile authentication based on a policy restricted to a single secrets group
  - one namespaced SecretStore with Trusted Profile authentication based on a policy restricted to multiple secrets groups
  - one namespaced SecretStore with Trusted Profile authentication based on a policy not restricted to any secrets group
- Creates/Loads the following resources to complete the mentioned use-cases
  - Loads an existing Secrets Manager instance or creates a new one
  - Creates Secrets Manager IAM engine configuration and secret group(s)
  - Creates service ID (secret-puller) configured with IAM policies to pull secrets from SM
  - Deploys a dockerconfigjson secret for an artifactory registry
    - Creates username_password Secrets Manager secret to store artifactory credentials
    - Deploys external secrets in designated namespace
    - Creates a ClusterSecretStore using API key authentication to access secrets from designated namespace
    - Installs and configures external secret operator
  - Deploys another dockerconfigjson secret for an artifactory registry
    - Deploys external secrets in designated namespace
    - Creates a ClusterSecretStore using Trusted Profile authentication to access secrets from designated namespace
  - Deploys an opaque secret for Cloudant credentials (temporary disabled due to issue https://github.ibm.com/GoldenEye/issues/issues/7726)
    - Creates Cloudant instance and resource key
    - Creates arbitrary Secrets Manager secret to store resource key
    - Deploys external secrets in designated namespace
    - Uses existing ClusterSecretStore to access secrets from designated namespace
  - Deploys a dockerconfigjson secret from an arbitrary secret to authenticate in container registry
    - Creates arbitrary Secrets Manager secret to store existing API key
    - Deploys external secrets in designated namespaces
    - Creates a SecretStore (using API key authentication) to access secrets from designated namespace
  - Deploys a dockerconfigjson secret from a dynamic IAM secret to authenticate in container registry
    - Creates ServiceID (imagePull) with IAM policies to read from container registry namespace
    - Creates IAM Secrets Manager secret and dynamic API key that is associated with a imagePull Service ID
    - Deploys external secrets in designated namespaces
    - Creates a SecretStore(using API key authentication) to access secrets from designated namespace
  - Deploys a dockerconfigjson secret from a set of dynamic IAM secrets to authenticate in a set of container registries
    - Creates a set of ServiceIDs (imagePull) with IAM policies to read from container registry namespace for each secret to create (`${var.prefix}-image-pull-service-id-chain-sec-1/2/3`)
    - Creates a set of IAM Secrets Manager secrets and dynamic API key that are associated with the imagePull ServiceIDs created at the step above
    - Deploys external secrets resource in designated namespaces for the dockerjsonconfig secret building the secrets chain and using an existing secrets store
  - Creates and deploys a set of arbitrary secrets to cover the different use-cases for namespaced SecretStores
  - Creates and deploys a public certificate through CIS integration and public certificate engine module
  - Creates and deploys a private certificate and private certificate engine module
  - Loads certificate components stored on Secrets Manager as arbitrary secrets and then use these to create and deploy an imported certificate with public and intermediate certificates and public certificate private key
  - Creates and deploys a key-value secret with single key-value couple
  - Creates and deploys a key-value secret with multiple key-value couples
  - Creates a dynamic secret on Secrets Manager from the sDNLB entitled service ID and configures an ExternalSecret CRD on the cluster to create and synch the sDNLB secret with the expected format


In order to create the intermediate certificate the following parameters are needed:
- imported_certificate_sm_id: Secrets Manager ID where the componenents for the imported certificate are stored
- imported_certificate_sm_region: region of the Secrets Manager instance where the componenents for the imported certificate are stored
- imported_certificate_intermediate_secret_id: secret ID to load the intermediate certificate component for the imported certificate
- imported_certificate_public_secret_id: secret ID to load the public certificate component for the imported certificate
- imported_certificate_private_secret_id: secret ID to load the private key component for the imported certificate

In order to generate the public certificate the following mutually exclusive parameters are needed:
1. `acme_letsencrypt_private_key`: the Let's Encrypt ACME private key value (more details available [here](https://cloud.ibm.com/docs/secrets-manager?topic=secrets-manager-prepare-order-certificates#create-acme-account))
2. Let's Encrypt ACME Secrets Manager secret details:
   - `acme_letsencrypt_private_key_secret_id`: secret ID to load the Let's Encrypt acme private key for the public certificate generation
   - `acme_letsencrypt_private_key_sm_id`: Secrets Manager ID where the Let's Encrypt acme private key for the public certificate generation is stored
   - `acme_letsencrypt_private_key_sm_region`: region of the Secrets Manager instance where the Let's Encrypt acme private key for the public certificate generation is stored

If a value is provided for `acme_letsencrypt_private_key` the other ones are not needed and not used, otherwise if it is **null** all the remaining ones (Secrets Manager ID, region and secret ID for Let's Encrypt ACME key) are needed to create a public certificate.

In the case all the mentioned parameters are left with their default **null** value, the related secrets will not be created.

The example is split into separated templates related with their specific scope:
- main.tf for the VPC, cluster, VPE, ESO operator deployment and namespaces preliminary creation
- clusterstore.tf for ESO ClusterSecretsStore configuration with API key authentication, including two different externalsecrets and secret types configuration (username/password and arbitrary)
- secretstore.tf for ESO secretstore configuration with API key authentication and namespace isolation, including two different externalsecrets and secrets configuration (arbitrary and image pull API key secret using imagepull-apikey-secrets-manager-module)
- secretsmanager.tf for Secrets Manager instance configuration, along with IAM serviceID and API keys and secrets groups
- kv.tf for key-value (single and multiple keys) secrets
- publiccertificate.tf for public certificate management
- privatecertificate.tf for private certificate management
- importedcertificate.tf for imported certificate management
- tpauth_namespaced_sstore.tf for ESO SecretsStore and externalsecret configuration with Trusted Profile authentication and namespace isolation
- tpauth_cluster_sstore.tf for ESO ClusterSecretsStore and externalsecret configuration with Trusted Profile authentication


## Important note about input region and existing SecretManager region parameters

Due to the https://github.ibm.com/GoldenEye/issues/issues/5268 the test is currently using the existing SecretManager region to deploy the VPC and the cluster if this value is not null. Instead if null it follows what set through `var.region`

This logic is achieved through the local `sm_region` variable that is then used to create resources.
