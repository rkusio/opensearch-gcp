output "data_cluster_name" {
  value = module.opensearch_data.cluster_name
}

output "data_cluster_lb_ip" {
  value = module.opensearch_data.lb_ip
}

output "data_cluster_masters" {
  value = module.opensearch_data.master_instances
}

output "data_cluster_migs" {
  value = module.opensearch_data.mig_instance_groups
}

output "monitoring_cluster_name" {
  value = module.opensearch_monitoring.cluster_name
}

output "monitoring_cluster_masters" {
  value = module.opensearch_monitoring.master_instances
}
