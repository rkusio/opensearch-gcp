locals {
  # Roles that use MIGs (scalable, rolling-updateable)
  mig_roles = toset([
    for role, config in var.node_configs : role
    if contains(["data", "data-hot", "coordinator"], role)
  ])

  # Roles that use individual instances (stable identity)
  instance_roles = toset([
    for role, config in var.node_configs : role
    if contains(["master", "dashboards", "master+data", "monitor"], role)
  ])

  # Master node names for seed discovery and initial masters
  # Roles that participate in master election
  master_role = contains(keys(var.node_configs), "master") ? "master" : (
    contains(keys(var.node_configs), "master+data") ? "master+data" : (
      contains(keys(var.node_configs), "monitor") ? "monitor" : null
    )
  )

  master_instance_prefix = {
    "master"     = "master"
    "master+data" = "node"
    "monitor"    = "monitor"
  }

  master_names = local.master_role != null ? flatten([
    for idx, zone in var.zones : [
      for i in range(var.node_configs[local.master_role].count_per_zone) :
      "${var.cluster_name}-${local.master_instance_prefix[local.master_role]}-${zone}-${i}"
    ]
  ]) : []

  # Seed hosts as DNS names
  seed_hosts = [
    for name in local.master_names :
    "${name}.${trimsuffix(var.dns_domain, ".")}"
  ]

  # Metadata shared across all node types
  base_metadata = {
    "opensearch-cluster-name"        = var.cluster_name
    "opensearch-seed-hosts"          = join(",", local.seed_hosts)
    "opensearch-initial-masters"     = join(",", local.master_names)
    "opensearch-force-zone-awareness" = tostring(var.force_zone_awareness)
  }

  # Common labels
  common_labels = merge(var.labels, {
    cluster     = var.cluster_name
    environment = var.environment
    managed-by  = "terraform"
  })

  # Flatten subnet map to zone-indexed
  zone_subnets = {
    for zone in var.zones :
    zone => [for k, v in var.subnet_self_links : v if can(regex(zone, k))][0]
  }
}

data "google_compute_image" "opensearch" {
  project = var.project_id
  name    = var.image
}
