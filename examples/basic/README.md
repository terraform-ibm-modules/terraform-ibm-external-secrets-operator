# Basic Example

This module provides a basic example to deploy the External Secrets Operator along with a simple username-password type secret in an IBM Cloud environment. It showcases a comprehensive implementation for managing secrets within a Kubernetes cluster, leveraging IBM Cloud's capabilities for a secure and efficient secret management system.

## Actions Performed

- **Resource Group Handling**: Loads an existing resource group or creates a new one based on the provided variables.

- **VPC and Subnet Configuration**: Establishes a Virtual Private Cloud (VPC) with associated subnets, setting up network segmentation and ACL rules.

- **OpenShift Cluster Provisioning**: Deploys an OpenShift (OCP) cluster, tailored for a cloud-native architecture with worker pools for private, transit, and edge network segments.

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
