##############################################################################
# Outputs
##############################################################################

output "cluster_crn" {
  description = "CRN of the cluster deployed"
  value       = module.ocp_base.cluster_crn
}
