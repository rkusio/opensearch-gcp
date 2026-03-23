variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "env_name" {
  type        = string
  description = "Environment name (e.g. dev-1, uat-1, prod)"
}

variable "subnets" {
  type = list(object({
    name          = string
    ip_cidr_range = string
  }))
  description = "Subnet definitions (one per zone)"
  default = [
    { name = "opensearch-a", ip_cidr_range = "10.0.1.0/24" },
    { name = "opensearch-b", ip_cidr_range = "10.0.2.0/24" },
    { name = "opensearch-c", ip_cidr_range = "10.0.3.0/24" },
  ]
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed for SSH access (use IAP range by default)"
  default     = ["35.235.240.0/20"] # IAP range
}

variable "allowed_dashboards_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access OpenSearch Dashboards (port 5601)"
  default     = ["10.0.0.0/8"]
}
