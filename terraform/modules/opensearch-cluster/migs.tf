# Zonal Managed Instance Groups for data, data-hot, coordinating nodes
# Uses OPPORTUNISTIC update policy — rolling updates are triggered by scripts

module "mig" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-mig?ref=v34.1.0"

  for_each = {
    for item in flatten([
      for role in local.mig_roles : [
        for zone in var.zones : {
          key  = "${role}-${zone}"
          role = role
          zone = zone
        }
      ]
    ]) : item.key => item
  }

  project_id        = var.project_id
  location          = each.value.zone
  name              = "${var.cluster_name}-${each.value.role}-${each.value.zone}"
  instance_template = module.instance_template[each.value.role].template.self_link
  target_size       = var.node_configs[each.value.role].count_per_zone

  update_policy = {
    type             = "OPPORTUNISTIC"
    minimal_action   = "REPLACE"
    max_surge        = { fixed = 1 }
    max_unavailable  = { fixed = 0 }
  }

  named_ports = {
    opensearch = 9200
  }

  health_check_config = {
    tcp = {
      port = 9200
    }
    check_interval_sec  = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout_sec         = 10
  }

  auto_healing_policies = {
    initial_delay_sec = 300
  }
}
