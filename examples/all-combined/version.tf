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
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.83.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1, < 4.0.0"
    }
  }
}
