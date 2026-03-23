packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.1.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "zone" {
  type        = string
  default     = "europe-central2-a"
  description = "Zone for Packer build instance"
}

variable "region" {
  type        = string
  default     = "europe-central2"
  description = "Region for the output image"
}

variable "opensearch_version" {
  type        = string
  default     = "2.17.0"
  description = "OpenSearch version to install"
}

variable "data_prepper_version" {
  type        = string
  default     = "2.9.0"
  description = "Data Prepper version to install"
}

variable "source_image_family" {
  type        = string
  default     = "rhel-9"
  description = "Source image family"
}

variable "source_image_project" {
  type        = string
  default     = "rhel-cloud"
  description = "Source image project"
}

variable "machine_type" {
  type        = string
  default     = "e2-standard-4"
  description = "Machine type for the build instance"
}

variable "network" {
  type        = string
  default     = "default"
  description = "VPC network for the build instance"
}

variable "subnetwork" {
  type        = string
  default     = ""
  description = "Subnetwork for the build instance (optional)"
}

source "googlecompute" "opensearch" {
  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = [var.source_image_project]
  zone                    = var.zone
  machine_type            = var.machine_type
  disk_size               = 20
  disk_type               = "pd-ssd"
  image_name              = "opensearch-${replace(var.opensearch_version, ".", "-")}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  image_family            = "opensearch"
  image_description       = "OpenSearch ${var.opensearch_version} on RHEL 9"
  image_storage_locations = [var.region]
  ssh_username            = "packer"
  tags                    = ["packer"]
  network                 = var.network
  subnetwork              = var.subnetwork != "" ? var.subnetwork : null
  use_internal_ip         = true
  omit_external_ip        = false

  metadata = {
    enable-oslogin = "FALSE"
  }
}

build {
  sources = ["source.googlecompute.opensearch"]

  provisioner "ansible" {
    playbook_file = "../ansible/playbook.yml"
    extra_arguments = [
      "--extra-vars",
      "opensearch_version=${var.opensearch_version} data_prepper_version=${var.data_prepper_version}",
    ]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_SSH_ARGS=-o IdentitiesOnly=yes",
    ]
  }
}
