# Individual instances for roles requiring stable identity
# (master, dashboards, master+data, monitor)

locals {
  instance_name_prefix = {
    "master"     = "master"
    "master+data" = "node"
    "monitor"    = "monitor"
    "dashboards" = "dashboards"
  }
}

module "instance" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm?ref=v34.1.0"

  for_each = {
    for item in flatten([
      for role in local.instance_roles : [
        for zone_idx, zone in var.zones : [
          for i in range(var.node_configs[role].count_per_zone) : {
            key  = "${role}-${zone}-${i}"
            role = role
            zone = zone
            name = "${var.cluster_name}-${lookup(local.instance_name_prefix, role, role)}-${zone}-${i}"
          }
        ]
      ]
    ]) : item.key => item
  }

  project_id = var.project_id
  zone       = each.value.zone
  name       = each.value.name

  instance_type = var.node_configs[each.value.role].machine_type

  boot_disk = {
    initialize_params = {
      image                  = data.google_compute_image.opensearch.self_link
      size                   = var.node_configs[each.value.role].boot_disk.size
      type                   = var.node_configs[each.value.role].boot_disk.type
      provisioned_iops       = var.node_configs[each.value.role].boot_disk.provisioned_iops
      provisioned_throughput = var.node_configs[each.value.role].boot_disk.provisioned_throughput
    }
  }

  attached_disks = var.node_configs[each.value.role].data_disk != null ? [
    {
      name = "opensearch-data"
      size = var.node_configs[each.value.role].data_disk.size
      options = {
        type                   = var.node_configs[each.value.role].data_disk.type
        provisioned_iops       = var.node_configs[each.value.role].data_disk.provisioned_iops
        provisioned_throughput = var.node_configs[each.value.role].data_disk.provisioned_throughput
      }
    }
  ] : []

  network_interfaces = [
    {
      network    = var.network_self_link
      subnetwork = local.zone_subnets[each.value.zone]
      nic_type   = var.node_configs[each.value.role].nic_type
    }
  ]

  metadata = merge(local.base_metadata, {
    "opensearch-node-role" = each.value.role
    # Dashboards need to know the OpenSearch endpoint (monitor role uses localhost)
    "opensearch-dashboards-hosts" = each.value.role == "dashboards" ? (
      "http://${var.cluster_name}-lb.${trimsuffix(var.dns_domain, ".")}:9200"
    ) : ""
  })

  service_account = {
    email  = module.service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["opensearch", "opensearch-${each.value.role}"]

  labels = merge(local.common_labels, {
    role = each.value.role
  })
}
