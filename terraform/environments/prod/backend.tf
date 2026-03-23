terraform {
  backend "gcs" {
    bucket = "opensearch-terraform-state"
    prefix = "environments/prod"
  }
}
