#!/usr/bin/env bash

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

rm -rf .terraform && \
mkdir -p .terraform && \

if [ -z ${1} ]; then
    code_path="${1}" && \
    cd "${code_path}" || print_error "Code path is empty or invalid" && exit 1
    else
      print_error "Code path is empty or invalid" && exit 1
fi

if [ -z ${2} ]; then
    workspace_name="${2}" && \
    printf '%s' "${workspace}" > .terraform/environment || print_error "Workspace name failed to create" && exit 1
    else
      print_alert "No terraform workspace has been applied, continuing..."
fi

if [ -z ${3} ]; then
    backend_sa_rg_name="${3}" || print_error "Variable assignment for backend storage account resource group failed or is invalid" && exit 1
    else
      print_error "Variable assignment for backend storage account resource group failed or is invalid" && exit 1
fi

if [ -z ${4} ]; then
    backend_sa_name="${4}" || print_error "Variable assignment for backend storage account name failed or is invalid" && exit 1
    else
      print_error "Variable assignment for backend storage account name failed or is invalid" && exit 1
fi

if [ -z ${5} ]; then
    backend_blob_container_name="${5}" || print_error "Variable assignment for backend storage account blob container failed or is invalid" && exit 1
    else
      print_error "Variable assignment for backend storage account blob container failed or is invalid" && exit 1
fi

if [ -z ${6} ]; then
    backend_state_name="${6}" || print_error "Variable assignment for backend state name failed or is invalid" && exit 1
    else
      print_error "Variable assignment for backend state name has failed or is invalid" && exit 1
fi

if [ -z ${7} ]; then
    provider_client_id="${7}" || print_error "Variable assignment for provider client id failed or is invalid" && exit 1
    else
      print_error "Variable assignment for provider client id has failed or is invalid" && exit 1
fi

if [ -z ${8} ]; then
    provider_client_secret="${8}" || print_error "Variable assignment for provider client secret failed or is invalid" && exit 1
    else
      print_error "Variable assignment for provider client secret has failed or is invalid" && exit 1
fi


if [ -z ${8} ]; then
    provider_client_subscription_id="${8}" || print_error "Variable assignment for provider subscription id failed or is invalid" && exit 1
    else
      print_error "Variable assignment for provider subscritpion id has failed or is invalid" && exit 1
fi

if [ -z ${8} ]; then
    provider_client_subscription_id="${8}" || print_error "Variable assignment for provider subscription id failed or is invalid" && exit 1
    else
      print_error "Variable assignment for provider subscritpion id has failed or is invalid" && exit 1
fi



terraform init \
-backend-config="resource_group_name=${3}" \
-backend-config="storage_account_name=${4}" \
-backend-config="access_key=${4}" \
-backend-config="container_name=${5}" \
-backend-config="key=${TF_VAR_short}-${TF_VAR_env}.terraform.tfstate" && \

printf '%s' "${TF_VAR_env}" > .terraform/environment && \

terraform workspace select "${2}" && \

terraform plan -destroy -out ${PIPELINE_PLAN} && \

terraform validate


