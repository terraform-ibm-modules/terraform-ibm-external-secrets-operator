terraform {
  required_version = ">= 1.1.0"
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
      source = "IBM-Cloud/ibm"
      # version = ">= 1.62.0
      version = ">= 1.62.0, < 1.76.0" # locking terraform provider version to 1.75.2 due to issue https://github.com/IBM-Cloud/terraform-provider-ibm/issues/6050
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1, < 4.0.0"
    }
  }
}
