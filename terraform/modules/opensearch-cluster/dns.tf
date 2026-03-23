# Cloud DNS private zone for master node seed host discovery

module "dns" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id = var.project_id
  name       = "${var.cluster_name}-dns"
  zone_config = {
    domain = var.dns_domain
    private = {
      client_networks = [var.network_self_link]
    }
  }

  recordsets = merge(
    # A records for master/node instances (stable identity)
    {
      for key, inst in module.instance : "A ${inst.instance.name}.${trimsuffix(var.dns_domain, ".")}" => {
        type    = "A"
        ttl     = 60
        records = [inst.internal_ip]
      }
    },
    # LB record for client access
    length(google_compute_forwarding_rule.opensearch) > 0 ? {
      "A ${var.cluster_name}-lb.${trimsuffix(var.dns_domain, ".")}" = {
        type    = "A"
        ttl     = 60
        records = [google_compute_forwarding_rule.opensearch[0].ip_address]
      }
    } : {}
  )
}
