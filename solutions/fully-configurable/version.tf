terraform {
  required_version = ">= 1.9.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.62.0"
    }
  }
}
