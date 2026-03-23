variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "europe-central2"
  description = "GCP region"
}

variable "zones" {
  type    = list(string)
  default = ["europe-central2-a", "europe-central2-b", "europe-central2-c"]
}

variable "opensearch_image" {
  type        = string
  description = "Packer-built OpenSearch image name"
}
