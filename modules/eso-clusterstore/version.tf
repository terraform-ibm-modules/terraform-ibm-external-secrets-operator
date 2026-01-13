terraform {
  required_version = ">= 1.9.0"
  required_providers {
    # Use "greater than or equal to" range in modules
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.1, <4.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0, <4.0.0"
    }
  }
}
