# Basic Example

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<a href="https://cloud.ibm.com/schematics/workspaces/create?workspace_name=external-secrets-operator-basic-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-external-secrets-operator/tree/main/examples/basic"><img src="https://img.shields.io/badge/Deploy%20with IBM%20Cloud%20Schematics-0f62fe?logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics" style="height: 16px; vertical-align: text-bottom;"></a>
<!-- END SCHEMATICS DEPLOY HOOK -->


This module provides a basic example to deploy the External Secrets Operator along with a simple username-password type secret in an IBM Cloud environment. It showcases a comprehensive implementation for managing secrets within a Kubernetes cluster, leveraging IBM Cloud's capabilities for a secure and efficient secret management system.

## Actions Performed

- **Resource Group Handling**: Loads an existing resource group or creates a new one based on the provided variables.

- **VPC and Subnet Configuration**: Establishes a Virtual Private Cloud (VPC) with associated subnets, setting up network segmentation and ACL rules.

- **OpenShift Cluster Provisioning**: Deploys an OpenShift (OCP) cluster, tailored for a cloud-native architecture with default worker pools .

- **Secrets Manager Integration**:
  - Either utilizes an existing Secrets Manager instance or creates a new one.
  - Configures IAM engine, policies, and secret groups to manage access and operations on secrets.

- **External Secrets Operator Configuration**:
  - Deploys the External Secrets Operator in the Kubernetes cluster.
  - Includes configurations for the External Secrets Operator to interact with the Secrets Manager and manage secrets at cluster and namespace levels.

- **Secret Management**:
  - Sets up a service ID (secret-puller) with IAM policies for accessing secrets from the Secrets Manager.
  - Configures various types of secrets, including IAM service ID API keys and username-password combinations.
  - Demonstrates the deployment of external secrets within Kubernetes, utilizing the configured `ClusterSecretStore` and `SecretStore` instances.

<!-- BEGIN SCHEMATICS DEPLOY TIP HOOK -->
:information_source: Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab
<!-- END SCHEMATICS DEPLOY TIP HOOK -->
