module "service_account" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v34.1.0"
  project_id = var.project_id
  name       = "${var.cluster_name}-node"

  iam_project_roles = {
    (var.project_id) = [
      "roles/compute.viewer",
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
    ]
  }
}
