terraform {
  required_version = ">= 1.9.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "2.7.0"
    }
  }
}
