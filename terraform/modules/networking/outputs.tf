output "network_self_link" {
  value       = module.vpc.self_link
  description = "VPC network self link"
}

output "network_id" {
  value       = module.vpc.id
  description = "VPC network ID"
}

output "subnet_self_links" {
  value = {
    for subnet in module.vpc.subnets : subnet.name => subnet.self_link
  }
  description = "Map of subnet name to self link"
}

output "subnet_ids" {
  value = {
    for subnet in module.vpc.subnets : subnet.name => subnet.id
  }
  description = "Map of subnet name to ID"
}
