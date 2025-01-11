##############################################################################
# Outputs
##############################################################################
# output "cluster_id" {
#   description = "ID of the cluster deployed"
#   value       = module.ocp_base.cluster_id
# }

output "vpc" {
  description = "Configuration of newly created or existing VPC instace."
  value       = module.vpc
}

# output "security_group" {
#   value = module.security_group
# }

# output "network_acl" {
#   value= module.network_acl
# }

# output "subnets" {
#   value = module.subnet
# }