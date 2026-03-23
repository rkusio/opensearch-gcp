output "cluster_name" {
  value       = var.cluster_name
  description = "OpenSearch cluster name"
}

output "master_instances" {
  value = {
    for key, inst in module.instance : key => {
      name        = inst.instance.name
      zone        = inst.instance.zone
      internal_ip = inst.internal_ip
    }
    if can(regex("master|node", key))
  }
  description = "Master/node instance details"
}

output "mig_instance_groups" {
  value = {
    for key, mig in module.mig : key => {
      name           = mig.group_manager.name
      zone           = mig.group_manager.zone
      instance_group = mig.group_manager.instance_group
    }
  }
  description = "MIG instance group details"
}

output "lb_ip" {
  value       = local.create_lb ? google_compute_forwarding_rule.opensearch[0].ip_address : null
  description = "Internal load balancer IP address"
}

output "service_account_email" {
  value       = module.service_account.email
  description = "Service account email used by OpenSearch instances"
}

output "dns_zone_name" {
  value       = module.dns.name
  description = "Cloud DNS zone name"
}
