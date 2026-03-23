module "vpc" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc?ref=v34.1.0"
  project_id = var.project_id
  name       = "opensearch-${var.env_name}"

  subnets = [
    for subnet in var.subnets : {
      name          = "${subnet.name}-${var.env_name}"
      ip_cidr_range = subnet.ip_cidr_range
      region        = var.region
    }
  ]
}

module "firewall_policy" {
  source    = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-firewall-policy?ref=v34.1.0"
  name      = "opensearch-${var.env_name}"
  parent_id = module.vpc.id

  attachments = {
    vpc = module.vpc.id
  }

  ingress_rules = {
    # Allow internal OpenSearch communication between all nodes
    allow-opensearch-internal = {
      priority = 1000
      match = {
        source_ranges  = [for s in var.subnets : s.ip_cidr_range]
        layer4_configs = [
          { protocol = "tcp", ports = ["9200", "9300", "9600"] },
        ]
      }
      action = "allow"
    }

    # Allow Dashboards access from allowed CIDRs
    allow-dashboards = {
      priority = 1100
      match = {
        source_ranges  = var.allowed_dashboards_cidrs
        layer4_configs = [{ protocol = "tcp", ports = ["5601"] }]
      }
      action = "allow"
    }

    # Allow SSH from IAP
    allow-iap-ssh = {
      priority = 1200
      match = {
        source_ranges  = var.allowed_ssh_cidrs
        layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
      }
      action = "allow"
    }

    # Allow GCP health check probes
    allow-health-checks = {
      priority = 1300
      match = {
        source_ranges  = ["130.211.0.0/22", "35.191.0.0/16"]
        layer4_configs = [{ protocol = "tcp", ports = ["9200"] }]
      }
      action = "allow"
    }
  }
}
