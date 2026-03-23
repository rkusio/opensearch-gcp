# Instance templates for MIG-managed roles (data, data-hot, coordinator)
# Created using CFF compute-vm with create_template = true

module "instance_template" {
  source   = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm?ref=v34.1.0"
  for_each = local.mig_roles

  project_id      = var.project_id
  zone            = var.zones[0]
  name            = "${var.cluster_name}-${each.key}"
  create_template = true

  instance_type = var.node_configs[each.key].machine_type

  boot_disk = {
    initialize_params = {
      image                  = data.google_compute_image.opensearch.self_link
      size                   = var.node_configs[each.key].boot_disk.size
      type                   = var.node_configs[each.key].boot_disk.type
      provisioned_iops       = var.node_configs[each.key].boot_disk.provisioned_iops
      provisioned_throughput = var.node_configs[each.key].boot_disk.provisioned_throughput
    }
  }

  attached_disks = var.node_configs[each.key].data_disk != null ? [
    {
      name = "opensearch-data"
      size = var.node_configs[each.key].data_disk.size
      options = {
        type                   = var.node_configs[each.key].data_disk.type
        provisioned_iops       = var.node_configs[each.key].data_disk.provisioned_iops
        provisioned_throughput = var.node_configs[each.key].data_disk.provisioned_throughput
      }
    }
  ] : []

  network_interfaces = [
    {
      network    = var.network_self_link
      subnetwork = local.zone_subnets[var.zones[0]]
      nic_type   = var.node_configs[each.key].nic_type
    }
  ]

  metadata = merge(local.base_metadata, {
    "opensearch-node-role" = each.key
  })

  service_account = {
    email  = module.service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["opensearch", "opensearch-${each.key}"]

  labels = merge(local.common_labels, {
    role = each.key
  })
}
