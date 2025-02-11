##############################################################################
# Outputs
##############################################################################

output "helm_release_secret_store" {
  value       = var.eso_authentication == "trusted_profile" ? helm_release.external_secret_store_tp : helm_release.external_secret_store_apikey
  description = "SecretStore helm release. Returning the helm release for trusted profile or apikey authentication according to the authentication type"
}
