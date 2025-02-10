##############################################################################
# Outputs
##############################################################################

output "trusted_profile_id" {
  value       = ibm_iam_trusted_profile.trusted_profile.id
  description = "ID of the trusted profile"
}

output "trusted_profile_name" {
  value       = ibm_iam_trusted_profile.trusted_profile.name
  description = "Name of the trusted profile"
}
