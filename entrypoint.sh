#!/usr/bin/env bash

set -e

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

print_alert "checkov version = $(print_success $(checkov --version))"
print_alert "tfsec version = $(print_success $(tfsec --version))"

print_alert "terraform-compliance version below"
terraform-compliance --version

print_alert "terraform version below"
terraform -v

# Prepare variables with better common names
if [[ -n "${1}" ]]; then
    terraform_path="${1}" && \
        cd "${terraform_path}"
else
    print_error "Code path is empty or invalid, check the following tree output and see if it is as you expect - Error - LDO_TF_CODE_PATH" && tree . && exit 1
fi

if [[ -n "${2}" ]]; then
    rm -rf .terraform && \
        mkdir -p ".terraform" && \
        touch ".terraform/environment"
    terraform_workspace_name="${2}" && \
        printf '%s' "${terraform_workspace_name}" | tee .terraform/environment >/dev/null
else
    print_error "Workspace variable appears to be empty or invalid, ensure that you can see - ${2} - if you cannot, set your workspace as a plain text chars and try again - Error - LDO_TF_WORKSPACE" && exit 1
fi

if [[ -n "${3}" ]]; then
    terraform_backend_sa_rg_name="${3}"
else
    print_error "Variable assignment for backend storage account resource group failed or is invalid, ensure it is correct and try again - Error LDO_TF_BACKEND_SA_RG_NAME" && exit 1
fi

if [[ -n "${4}" ]]; then
    terraform_backend_sa_name="${4}"
else
    print_error "Variable assignment for backend storage account name failed or is invalid, ensure it is correct and try again - Error LDO_TF_BACKEND_SA_NAME" && exit 1
fi

if [[ -n "${5}" ]]; then
    terraform_backend_blob_container_name="${5}"
else
    print_error "Variable assignment for backend storage account blob container failed or is invalid, ensure it is correct and try again - Error LDO_TF_BACKEND_BLOB_CONTAINER_NAME" && exit 1
fi

if [[ -n "${6}" ]]; then
    terraform_backend_storage_access_key="${6}"
else
    print_error "Variable assignment for backend storage access key name has failed or is invalid, ensure it is correct and try again - Error LDO_TF_BACKEND_SA_ACCESS_KEY" && exit 1
fi

if [[ -n "${7}" ]]; then
    terraform_backend_state_name="${7}"
else
    print_error "Variable assignment for backend state name has failed or is invalid, ensure you are providing a canonical statefile name - Error LDO_TF_BACKEND_STATE_NAME" && exit 1
fi

if [[ -n "${8}" ]]; then
    terraform_provider_client_id="${8}"
else
    print_error "Variable assignment for provider client id has failed or is invalid,  ensure it is correct and try again - Error LDO_TF_AZURERM_PROVIDER_CLIENT_ID" && exit 1
fi

if [[ -n "${9}" ]]; then
    terraform_provider_client_secret="${9}"
else
    print_error "Variable assignment for provider client secret has failed or is invalid, ensure it is correct and try again - Error LDO_TF_AZURERM_PROVIDER_CLIENT_SECRET" && exit 1
fi

if [[ -n "${10}" ]]; then
    terraform_provider_client_subscription_id="${10}"
else
    print_error "Variable assignment for provider subscription id has failed or is invalid, ensure it is correct and try again - Error LDO_TF_AZURERM_PROVIDER_SUBSCRIPTION_ID" && exit 1
fi

if [[ -n "${11}" ]]; then
    terraform_provider_client_tenant_id="${11}"
else
    print_error "Variable assignment for provider tenant id has failed or is invalid, ensure it is correct and try again - Error LDO_TF_AZURERM_PROVIDER_TENANT_ID" && exit 1
fi

if [[ -n "${12}" ]]; then
    terraform_compliance_path="${12}"
else
    print_error "Terraform compliance path is invalid or empty, ensure you are using either a accurate local path or remote git path which the action can access try again - Error LDO_TF_TERRAFORM_COMPLIANCE" && exit 1
fi

if [[ -n "${13}" ]]; then
    checkov_skipped_test="${13}"
else
    checkov_skipped_test=""
fi

if [[ -n "${14}" ]]; then
    run_terraform_destroy="${14}"
else
    print_error "Terraform destroy is empty, it must be either true or false - change this and try again - Error code - LDO_TF_TERRAFORM_DESTROY" && exit 1
fi

if [[ -n "${15}" ]]; then
    run_terraform_plan_only="${15}"
else
    print_error "Terraform Plan only is empty, it must be either true or false - change this and try again - Error code - LDO_TF_TERRAFORM_PLAN_ONLY" && exit 1
fi

export ARM_CLIENT_ID="${terraform_provider_client_id}"
export ARM_CLIENT_SECRET="${terraform_provider_client_secret}"
export ARM_SUBSCRIPTION_ID="${terraform_provider_client_subscription_id}"
export ARM_TENANT_ID="${terraform_provider_client_tenant_id}"

# Run Terraform Plan Only
if [ "${run_terraform_destroy}" = "false" ] && [ "${run_terraform_plan_only}"  = "true" ]; then

    terraform init \
        -backend-config="resource_group_name=${terraform_backend_sa_rg_name}" \
        -backend-config="storage_account_name=${terraform_backend_sa_name}" \
        -backend-config="access_key=${terraform_backend_storage_access_key}" \
        -backend-config="container_name=${terraform_backend_blob_container_name}" \
        -backend-config="key=${terraform_backend_state_name}" && \

        terraform workspace new "${terraform_workspace_name}" || terraform workspace select "${terraform_workspace_name}"

    terraform validate && \

        terraform plan -out pipeline.plan && \

        print_alert "Running terraform-compliance now..."

    terraform-compliance -p pipeline.plan -f "${terraform_compliance_path}" && \

        print_alert "Running tfsec now..."

    tfsec && \

        terraform show -json pipeline.plan | tee pipeline.plan.json >/dev/null && \

        print_alert "Running checkov now..."

    checkov -f pipeline.plan.json --skip-check "${checkov_skipped_test}" && \

        print_success "Build ran successfully" || { print_error "Build Failed" ; exit 1; }

    # Run Terraform Plan and Terraform Apply
elif [ "${run_terraform_destroy}" = "false" ] && [ "${run_terraform_plan_only}"  = "false" ]; then

    terraform init \
        -backend-config="resource_group_name=${terraform_backend_sa_rg_name}" \
        -backend-config="storage_account_name=${terraform_backend_sa_name}" \
        -backend-config="access_key=${terraform_backend_storage_access_key}" \
        -backend-config="container_name=${terraform_backend_blob_container_name}" \
        -backend-config="key=${terraform_backend_state_name}" && \

        terraform workspace new "${terraform_workspace_name}" || terraform workspace select "${terraform_workspace_name}"

    terraform validate && \

        terraform plan -out pipeline.plan && \

        print_alert "Running terraform-compliance now..."

    terraform-compliance -p pipeline.plan -f "${terraform_compliance_path}" && \

        print_alert "Running tfsec now..."

    tfsec && \

        terraform show -json pipeline.plan | tee pipeline.plan.json >/dev/null && \

        print_alert "Running checkov now..."

    checkov -f pipeline.plan.json --skip-check "${checkov_skipped_test}" && \

        print_alert "Running terraform apply now..."

    terraform apply -auto-approve pipeline.plan

    print_success "Build ran successfully" || { print_error "Build Failed" ; exit 1; }

    # Run Terraform Plan -Destroy only
elif [ "${run_terraform_destroy}" = "true" ] && [ "${run_terraform_plan_only}"  = "true" ]; then

    terraform init \
        -backend-config="resource_group_name=${terraform_backend_sa_rg_name}" \
        -backend-config="storage_account_name=${terraform_backend_sa_name}" \
        -backend-config="access_key=${terraform_backend_storage_access_key}" \
        -backend-config="container_name=${terraform_backend_blob_container_name}" \
        -backend-config="key=${terraform_backend_state_name}" && \

        terraform workspace new "${terraform_workspace_name}" || terraform workspace select "${terraform_workspace_name}"

    terraform validate && \

        terraform plan -destroy -out pipeline.plan && \

        print_success "Build ran successfully" || { print_error "Build Failed" ; exit 1; }

    # Run terraform plan -destroy and terraform apply
elif [ "${run_terraform_destroy}" = "true" ] && [ "${run_terraform_plan_only}"  = "false" ]; then

    terraform init \
        -backend-config="resource_group_name=${terraform_backend_sa_rg_name}" \
        -backend-config="storage_account_name=${terraform_backend_sa_name}" \
        -backend-config="access_key=${terraform_backend_storage_access_key}" \
        -backend-config="container_name=${terraform_backend_blob_container_name}" \
        -backend-config="key=${terraform_backend_state_name}" && \

        terraform workspace new "${terraform_workspace_name}" || terraform workspace select "${terraform_workspace_name}"

    terraform validate && \

        terraform plan -destroy -out pipeline.plan && \

        print_alert "Running terraform apply now...  Note, this is a terraform destroy run"

    terraform apply -auto-approve pipeline.plan

    print_success "Build ran successfully" || { print_error "Build Failed" ; exit 1; }

else

    print_error "Something went wrong with the build, check for errors and retry" ; exit 1

fi