.PHONY: help init plan apply deploy destroy get
.DEFAULT_GOAL := help

env = production
blue_desired_capacity = 0
green_desired_capacity = 0
option := -var-file=$(env).tfvars -var 'blue_desired_capacity=$(blue_desired_capacity)' -var 'green_desired_capacity=$(green_desired_capacity)'

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Initialize a Terraform configuration
	rm -f .terraform/terraform.tfstate
	terraform init \
		-backend-config='backend.tfvars'
	-terraform workspace new production
	-terraform workspace new development

plan: get ## Generate and show an execution plan
	terraform workspace select $(env)
	terraform plan $(option)

apply: get ## Builds or changes infrastructure
	terraform workspace select $(env)
	terraform apply $(option) -auto-approve

deploy: get ## Builds or changes infrastructure and autoscaling group
	terraform workspace select $(env)
	./deploy.sh $(env)

destroy: get ## Destroy Terraform-managed infrastructure
	terraform workspace select $(env)
	terraform destroy $(option)

get: ## Download and install modules for the configuration
	terraform get
