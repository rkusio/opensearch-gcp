# Default variable values for Packer build
# Override with: packer build -var-file=variables.pkrvars.hcl opensearch.pkr.hcl

project_id           = "your-gcp-project-id"
zone                 = "europe-central2-a"
region               = "europe-central2"
opensearch_version   = "2.17.0"
data_prepper_version = "2.9.0"
source_image_family  = "rhel-9"
machine_type         = "e2-standard-4"
network              = "default"
