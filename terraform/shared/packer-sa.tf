resource "google_service_account" "packer" {
  project      = var.project_id
  account_id   = "packer-opensearch"
  display_name = "Packer OpenSearch Image Builder"
}

resource "google_project_iam_member" "packer_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.packer.email}"
}

resource "google_project_iam_member" "packer_image_user" {
  project = var.project_id
  role    = "roles/compute.imageUser"
  member  = "serviceAccount:${google_service_account.packer.email}"
}

resource "google_project_iam_member" "packer_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.packer.email}"
}

output "packer_service_account_email" {
  value = google_service_account.packer.email
}
