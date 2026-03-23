terraform {
  backend "gcs" {
    bucket = "opensearch-terraform-state"
    prefix = "environments/dev-3"
  }
}
