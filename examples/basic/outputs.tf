##############################################################################
# Outputs
##############################################################################
# output "cluster_id" {
#   description = "ID of the cluster deployed"
#   value       = module.ocp_base.cluster_id
# }

output "vpc" {
  description = "Configuration of newly created or existing VPC instace."
  value       =  module.vpc
}
