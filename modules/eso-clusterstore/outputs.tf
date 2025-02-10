##############################################################################
# Outputs
##############################################################################

output "helm_release_cluster_store" {
  value       = var.eso_authentication == "trusted_profile" ? helm_release.cluster_secret_store_tp : helm_release.cluster_secret_store_apikey
  description = "ClusterSecretStore helm release. Returning the helm release for trusted profile or apikey authentication according to the authentication type"
}
