terraform {
  required_version = ">= 1.9.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0, <4.0.0"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.52.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 1.18.0"
    }
  }
}
