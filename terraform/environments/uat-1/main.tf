terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "networking" {
  source     = "../../modules/networking"
  project_id = var.project_id
  region     = var.region
  env_name   = "uat-1"

  subnets = [
    { name = "opensearch-a", ip_cidr_range = "10.20.1.0/24" },
    { name = "opensearch-b", ip_cidr_range = "10.20.2.0/24" },
    { name = "opensearch-c", ip_cidr_range = "10.20.3.0/24" },
  ]
}

module "opensearch" {
  source            = "../../modules/opensearch-cluster"
  project_id        = var.project_id
  region            = var.region
  zones             = var.zones
  cluster_name      = "opensearch-uat-1"
  environment       = "uat"
  image             = var.opensearch_image
  network_self_link = module.networking.network_self_link
  subnet_self_links = module.networking.subnet_self_links
  dns_domain        = "uat-1.opensearch.internal."

  node_configs = {
    "master" = {
      machine_type   = "n2-standard-4"
      count_per_zone = 1
      boot_disk = {
        size = 20
        type = "pd-ssd"
      }
    }
    "data" = {
      machine_type   = "n2-standard-8"
      count_per_zone = 1
      boot_disk = {
        size = 20
        type = "pd-balanced"
      }
      data_disk = {
        size = 300
        type = "pd-balanced"
      }
    }
    "dashboards" = {
      machine_type   = "e2-standard-2"
      count_per_zone = 1
      boot_disk = {
        size = 20
        type = "pd-balanced"
      }
    }
  }
}
