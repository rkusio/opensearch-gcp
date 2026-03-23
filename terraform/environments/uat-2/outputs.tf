output "cluster_name" {
  value = module.opensearch.cluster_name
}

output "lb_ip" {
  value = module.opensearch.lb_ip
}

output "master_instances" {
  value = module.opensearch.master_instances
}
