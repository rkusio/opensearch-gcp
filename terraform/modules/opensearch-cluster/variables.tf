variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "zones" {
  type        = list(string)
  description = "List of 3 zones for HA deployment"
}

variable "cluster_name" {
  type        = string
  description = "OpenSearch cluster name"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, uat, prod)"
}

variable "image" {
  type        = string
  description = "Packer-built image name or self_link for OpenSearch nodes"
}

variable "network_self_link" {
  type        = string
  description = "VPC network self link"
}

variable "subnet_self_links" {
  type        = map(string)
  description = "Map of zone/subnet name to subnet self link"
}

variable "dns_zone_name" {
  type        = string
  description = "Cloud DNS managed zone name"
  default     = ""
}

variable "dns_domain" {
  type        = string
  description = "DNS domain for the cluster (e.g. opensearch.internal.)"
  default     = "opensearch.internal."
}

# ---------------------------------------------------------------------------
# Per-role node configuration
# ---------------------------------------------------------------------------
variable "node_configs" {
  type = map(object({
    machine_type   = string
    count_per_zone = number
    boot_disk = object({
      size                   = number
      type                   = string
      provisioned_iops       = optional(number)
      provisioned_throughput = optional(number)
    })
    data_disk = optional(object({
      size                   = number
      type                   = string
      provisioned_iops       = optional(number)
      provisioned_throughput = optional(number)
    }))
    nic_type = optional(string)
  }))
  description = <<-EOT
    Map of node role to instance configuration.
    Keys: master, data, data-hot, coordinator, dashboards, master+data, monitor
  EOT
}

variable "force_zone_awareness" {
  type        = bool
  default     = false
  description = "Enable forced zone awareness (prod only)"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels to apply to all resources"
}
