terraform {
  required_version = ">= 1.9.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.88.0"
    }
  }
}
