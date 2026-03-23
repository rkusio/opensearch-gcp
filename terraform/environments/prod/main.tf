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

# ---------------------------------------------------------------------------
# Networking (shared by data cluster and monitoring cluster)
# ---------------------------------------------------------------------------
module "networking" {
  source     = "../../modules/networking"
  project_id = var.project_id
  region     = var.region
  env_name   = "prod"

  subnets = [
    { name = "opensearch-a", ip_cidr_range = "10.30.1.0/24" },
    { name = "opensearch-b", ip_cidr_range = "10.30.2.0/24" },
    { name = "opensearch-c", ip_cidr_range = "10.30.3.0/24" },
  ]
}

# ---------------------------------------------------------------------------
# Data Cluster (main OpenSearch cluster)
# ---------------------------------------------------------------------------
module "opensearch_data" {
  source            = "../../modules/opensearch-cluster"
  project_id        = var.project_id
  region            = var.region
  zones             = var.zones
  cluster_name      = "opensearch-prod"
  environment       = "prod"
  image             = var.opensearch_image
  network_self_link = module.networking.network_self_link
  subnet_self_links = module.networking.subnet_self_links
  dns_domain        = "prod.opensearch.internal."

  force_zone_awareness = true

  node_configs = {
    # Dedicated master nodes — N2, lightweight
    "master" = {
      machine_type   = "n2-standard-4"
      count_per_zone = 1
      boot_disk = {
        size = 20
        type = "pd-ssd"
      }
    }

    # Data nodes — N4 with Hyperdisk Balanced for high throughput
    "data" = {
      machine_type   = "n4-standard-16"
      count_per_zone = 2
      boot_disk = {
        size                   = 20
        type                   = "hyperdisk-balanced"
        provisioned_iops       = 3000
        provisioned_throughput = 140
      }
      data_disk = {
        size                   = 1000
        type                   = "hyperdisk-balanced"
        provisioned_iops       = 15000
        provisioned_throughput = 240
      }
      nic_type = "GVNIC"
    }

    # Hot-tier data nodes — N4 with high-IOPS Hyperdisk
    "data-hot" = {
      machine_type   = "n4-standard-8"
      count_per_zone = 1
      boot_disk = {
        size                   = 20
        type                   = "hyperdisk-balanced"
        provisioned_iops       = 3000
        provisioned_throughput = 140
      }
      data_disk = {
        size                   = 500
        type                   = "hyperdisk-balanced"
        provisioned_iops       = 30000
        provisioned_throughput = 500
      }
      nic_type = "GVNIC"
    }

    # Coordinator nodes — handle client requests, no data
    "coordinator" = {
      machine_type   = "n2-standard-4"
      count_per_zone = 1
      boot_disk = {
        size = 20
        type = "pd-ssd"
      }
    }

    # Dashboards — 2 instances (zone-a and zone-b)
    "dashboards" = {
      machine_type   = "e2-standard-2"
      count_per_zone = 1
      boot_disk = {
        size = 20
        type = "pd-balanced"
      }
    }
  }

  labels = {
    team = "platform"
    tier = "production"
  }
}

# ---------------------------------------------------------------------------
# Monitoring Cluster (collects metrics, displays dashboards)
# ---------------------------------------------------------------------------
module "opensearch_monitoring" {
  source            = "../../modules/opensearch-cluster"
  project_id        = var.project_id
  region            = var.region
  zones             = var.zones
  cluster_name      = "opensearch-monitoring"
  environment       = "prod"
  image             = var.opensearch_image
  network_self_link = module.networking.network_self_link
  subnet_self_links = module.networking.subnet_self_links
  dns_domain        = "monitoring.opensearch.internal."

  node_configs = {
    # All-in-one monitor nodes: master + data + dashboards on same machine
    # 3 nodes total (1 per zone) for cost efficiency
    "monitor" = {
      machine_type   = "n2-standard-4"
      count_per_zone = 1
      boot_disk = {
        size = 20
        type = "pd-balanced"
      }
      data_disk = {
        size = 200
        type = "pd-balanced"
      }
    }
  }

  labels = {
    team = "platform"
    tier = "production"
    role = "monitoring"
  }
}
