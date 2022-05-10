#!/usr/bin/env bash

set -xe

print_success() {
  lightcyan='\033[1;36m'
  nocolor='\033[0m'
  echo -e "${lightcyan}$1${nocolor}"
}

print_error() {
  lightred='\033[1;31m'
  nocolor='\033[0m'
  echo -e "${lightred}$1${nocolor}"
}

print_alert() {
  yellow='\033[1;33m'
  nocolor='\033[0m'
  echo -e "${yellow}$1${nocolor}"
}

tree .

if [[ ! -z "${1}" ]]; then
    terraform_path="${1}" && \
    cd "${terraform_path}" && ls -lah
    else
      print_error "Code path is empty or invalid" && exit 1
fi

if [[ ! -z "${2}" ]]; then
    rm -rf .terraform && \
    mkdir -p ".terraform" && \
    touch ".terraform/environment"
    terraform_workspace_name="${2}" && \
    printf '%s' "${terraform_workspace_name}" | tee .terraform/environment
    else
       print_error "Workspace name failed to create" && exit 1
fi

if [[ ! -z "${3}" ]]; then
    terraform_backend_sa_rg_name="${3}"
    else
      print_error "Variable assignment for backend storage account resource group failed or is invalid" && exit 1
fi

if [[ ! -z "${4}" ]]; then
    terraform_backend_sa_name="${4}"
    else
      print_error "Variable assignment for backend storage account name failed or is invalid" && exit 1
fi

if [[ ! -z "${5}" ]]; then
    terraform_backend_blob_container_name="${5}"
    else
      print_error "Variable assignment for backend storage account blob container failed or is invalid" && exit 1
fi

if [[ ! -z "${6}" ]]; then
    terraform_backend_storage_access_key="${6}"
    else
      print_error "Variable assignment for backend storage access key name has failed or is invalid" && exit 1
fi

if [[ ! -z "${7}" ]]; then
    terraform_backend_state_name="${7}"
    else
      print_error "Variable assignment for backend state name has failed or is invalid" && exit 1
fi

if [[ ! -z "${8}" ]]; then
    terraform_provider_client_id="${8}"
    else
      print_error "Variable assignment for provider client id has failed or is invalid" && exit 1
fi

if [[ ! -z "${9}" ]]; then
    terraform_provider_client_secret="${9}"
    else
      print_error "Variable assignment for provider client secret has failed or is invalid" && exit 1
fi


if [[ ! -z "${10}" ]]; then
    terraform_provider_client_subscription_id="${10}"
    else
      print_error "Variable assignment for provider subscritpion id has failed or is invalid" && exit 1
fi

if [[ ! -z "${11}" ]]; then
    terraform_provider_client_tenant_id="${11}"
    else
      print_error "Variable assignment for provider tenant id has failed or is invalid" && exit 1
fi

if [[ ! -z "${12}" ]]; then
    terraform_compliance_path="${12}"
    else
      print_error "Terraform compliance path is invalid or empty" && exit 1
fi

if [[ ! -z "${13}" ]]; then
    checkov_skipped_test="${13}"
    else
    checkov_skipped_test="" || print_error "Checkov Skipped  is invalid or empty" && exit 1
fi

if [[ ! -z "${14}" ]]; then
    run_terrafrom_destroy="${14}"
    else
    print_error "Terraform destroy is empty" && exit 1
fi

export ARM_CLIENT_ID="${terraform_provider_client_id}"
export ARM_CLIENT_SECRET="${terraform_provider_client_secret}"
export ARM_SUBSCRIPTION_ID="${terraform_provider_client_subscription_id}"
export ARM_TENANT_ID="${terraform_provider_client_tenant_id}"

if [ "${run_terrafrom_destroy}" = "false" ]; then

terraform init \
-backend-config="resource_group_name=${terraform_backend_sa_rg_name}" \
-backend-config="storage_account_name=${terraform_backend_sa_name}" \
-backend-config="access_key=${terraform_backend_storage_access_key}" \
-backend-config="container_name=${terraform_backend_blob_container_name}" \
-backend-config="key=${terraform_backend_state_name}" && \

terraform workspace select "${terraform_workspace_name}" && \

terraform validate && \

terraform plan -out pipeline.plan && \
terraform-compliance -p pipeline.plan -f "${terraform_compliance_path}" && \
tfsec && \
terraform show -json pipeline.plan > pipeline.plan.json && \
checkov -f pipeline.plan.json --skip-check "${checkov_skipped_test}" && \

terraform apply -auto-approve pipeline.plan

elif [ "${run_terrafrom_destroy}" = "true" ]; then

    terraform init \
-backend-config="resource_group_name=${terraform_backend_sa_rg_name}" \
-backend-config="storage_account_name=${terraform_backend_sa_name}" \
-backend-config="access_key=${terraform_backend_storage_access_key}" \
-backend-config="container_name=${terraform_backend_blob_container_name}" \
-backend-config="key=${terraform_backend_state_name}" && \

terraform workspace select "${terraform_workspace_name}" && \

terraform validate && \

terraform plan -destroy -out pipeline.plan && \
terraform apply -auto-approve pipeline.plan

fi

print_successn "Build ran sccessfully"
