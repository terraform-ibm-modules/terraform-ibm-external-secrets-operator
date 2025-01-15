##############################################################################
# Outputs
##############################################################################


output "cluster_id" {
  description = "ID of the cluster deployed"
  value       = module.ocp_base.cluster_id
}

output "subnets" {
  description = "List of subnet"
  value       = local.subnets
}
