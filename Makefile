.PHONY: help build-image deploy-% plan-% rolling-update-% rotate-% fmt lint

PROJECT_ID ?= your-gcp-project-id
REGION ?= europe-central2
ZONES ?= europe-central2-a,europe-central2-b,europe-central2-c
OS_VERSION ?= 3.5.0

help: ## Show this help
	@grep -E '^[a-zA-Z_%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Image
# ---------------------------------------------------------------------------

build-image: ## Build a new OpenSearch Packer image
	./scripts/build-image.sh --project-id $(PROJECT_ID) --os-version $(OS_VERSION)

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------

init-%: ## Initialize Terraform for an environment (e.g. make init-dev-1)
	cd terraform/environments/$* && terraform init

plan-%: ## Plan Terraform for an environment (e.g. make plan-dev-1)
	cd terraform/environments/$* && terraform plan

deploy-%: ## Deploy an environment (e.g. make deploy-dev-1)
	cd terraform/environments/$* && terraform apply

destroy-%: ## Destroy an environment (e.g. make destroy-dev-1)
	cd terraform/environments/$* && terraform destroy

# ---------------------------------------------------------------------------
# Rolling Update
# ---------------------------------------------------------------------------

rolling-update-%: ## Rolling update for an environment (e.g. make rolling-update-prod ROLE=data ENDPOINT=http://10.0.0.1:9200)
	./scripts/rolling-update.sh \
		--project $(PROJECT_ID) \
		--cluster opensearch-$* \
		--endpoint $(ENDPOINT) \
		--region $(REGION) \
		--zones $(ZONES) \
		--role $(ROLE) \
		--new-template $(TEMPLATE)

rotate-%: ## Monthly rotation for an environment (e.g. make rotate-prod ENDPOINT=http://10.0.0.1:9200)
	./scripts/rotate-monthly.sh \
		--project $(PROJECT_ID) \
		--environment $* \
		--endpoint $(ENDPOINT) \
		--region $(REGION) \
		--zones $(ZONES) \
		--os-version $(OS_VERSION)

# ---------------------------------------------------------------------------
# Code quality
# ---------------------------------------------------------------------------

fmt: ## Format all Terraform and Packer files
	terraform fmt -recursive terraform/
	packer fmt packer/

lint: ## Validate Terraform and Packer configurations
	@for env in terraform/environments/*/; do \
		echo "Validating $${env}..."; \
		cd "$${env}" && terraform validate && cd - > /dev/null; \
	done
	cd packer && packer validate opensearch.pkr.hcl

# ---------------------------------------------------------------------------
# Shared infra
# ---------------------------------------------------------------------------

init-shared: ## Initialize shared Terraform (state bucket, service accounts)
	cd terraform/shared && terraform init

deploy-shared: ## Deploy shared infrastructure
	cd terraform/shared && terraform apply -var="project_id=$(PROJECT_ID)"
