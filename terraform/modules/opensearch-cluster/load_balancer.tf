# Internal TCP Load Balancer for OpenSearch client access (port 9200)
# Routes to coordinating nodes (prod) or data nodes (dev/UAT)

locals {
  # Determine which MIG backends to use for the LB
  lb_role = contains(keys(var.node_configs), "coordinator") ? "coordinator" : "data"

  lb_backends = {
    for key, mig in module.mig : key => mig
    if startswith(key, local.lb_role)
  }

  # Only create LB if there are MIG backends
  create_lb = length(local.lb_backends) > 0
}

# Health check for the LB
resource "google_compute_health_check" "opensearch" {
  count = local.create_lb ? 1 : 0

  project = var.project_id
  name    = "${var.cluster_name}-hc"

  tcp_health_check {
    port = 9200
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Backend service
resource "google_compute_region_backend_service" "opensearch" {
  count = local.create_lb ? 1 : 0

  project               = var.project_id
  name                  = "${var.cluster_name}-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_health_check.opensearch[0].id]

  dynamic "backend" {
    for_each = local.lb_backends
    content {
      group = backend.value.group_manager.instance_group
    }
  }
}

# Forwarding rule
resource "google_compute_forwarding_rule" "opensearch" {
  count = local.create_lb ? 1 : 0

  project               = var.project_id
  name                  = "${var.cluster_name}-fwd"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.opensearch[0].id
  ports                 = ["9200"]
  network               = var.network_self_link
  subnetwork            = values(var.subnet_self_links)[0]

  labels = local.common_labels
}
