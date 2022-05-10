# Libre DevOps - Azure Terraform GitHub Action

Hello :wave:

This is a repository for the heavily opinionated GitHub Action to run Terraform, mainly targetting Azure. As stated, this action is opinionated, in that it expects all parameters to provided to it, and will only run on the assumption these work - or else, it should error.  It is mainly used for the development of Libre DevOps terraform modules - but could be used by others, but be aware that it is not for everyone!

## What it does

- Pulls a Docker container - `ghcr.io/libre-devops/azure-terraform-gh-action-base:latest`
- Runs a Standard Terraform Workflow as Follows:
```shell
terraform init
terraform workspace new ${workspace_name}
terraform validate
terraform plan
``` 

- Then, based on some parameters to the action, will run other parts:
```shell
terraform plan -destroy
terraform apply
terraform-compliance
tfsec
checkov
```

### Example Usage

Check out the [workflows](https://github.com/libre-devops/azure-terraform-gh-action/tree/main/.github/workflows) folder for more examples

```yaml
name: 'Terraform Plan'

#Allow run manually or on push to main or in PR closure
on:
  push:
    branches:
    - main
  pull_request:
    types: [closed]
  workflow_dispatch:

jobs:
  azure-terraform-job:
    name: 'Terraform Build'
    runs-on: ubuntu-latest
    environment: tst

    # Use the Bash shell regardless whether the GitHub Actions runner is ubuntu-latest, macos-latest, or windows-latest
    defaults:
      run:
        shell: bash

    steps:
      - uses: actions/checkout@v3

      - name: Libre DevOps Terraform GitHub Action
        id: terraform-build
        uses: libre-devops/azure-terraform-gh-action@v1
        with:
          terraform-path: "terraform"
          terraform-workspace-name: "dev"
          terraform-backend-storage-rg-name: ${{ secrets.SpokeSaRgName }}
          terraform-backend-storage-account-name: ${{ secrets.SpokeSaName }}
          terraform-backend-blob-container-name: ${{ secrets.SpokeSaBlobContainerName }}
          terraform-backend-storage-access-key: ${{ secrets.SpokeSaPrimaryKey }}
          terraform-backend-state-name: "lbdo-dev-gh.terraform.tfstate"
          terraform-provider-client-id: ${{ secrets.SpokeSvpClientId }}
          terraform-provider-client-secret: ${{ secrets.SpokeSvpClientSecret }}
          terraform-provider-subscription-id: ${{ secrets.SpokeSubId }}
          terraform-provider-tenant-id: ${{ secrets.SpokeTenantId }}
          terraform-compliance-path: "git:https://github.com/craigthackerx/azure-terraform-compliance-naming-convention.git//?ref=main"
          checkov-skipped-tests: "CKV_AZURE_2"
          run-terraform-destroy: "false"
          run-terraform-plan-only: "true"

```

### Logic

```
if run-terraform-destroy = false AND run-terraform-plan-only = true == Run terraform plan but NEVER run terraform apply
if run-terraform-destroy = true AND run-terraform-plan-only = true == Run terraform plan -destroy but NEVER run terraform apply
if run-terraform-destroy = false AND run-terraform-plan-only = false == Run terraform plan AND run terraform apply
if run-terraform-destroy = run AND run-terraform-plan-only = false == Run terraform plan -destroy AND run terraform apply
```


### Inputs

```yaml
  terraform-path:
    description: 'The absolute path in Linux format to your terraform code'
    required: true

  terraform-workspace-name:
    description: 'The name of a terraform workspace, should be in plain text string'
    required: true
    
  terraform-backend-storage-rg-name:
    description: 'The name of resource group your storage account exists in,  needed for state file storage'
    required: true

  terraform-backend-storage-account-name:
    description: 'The name of your storage account , needed for state file storage'
    required: true

  terraform-backend-blob-container-name:
    description: 'The name of your storage account blob container, needed for state file storage'
    required: true

  terraform-backend-storage-access-key:
    description: 'The key to access your storage account, needed for state file storage'
    required: true

  terraform-backend-state-name:
    description: 'The name of your statefilee, needed for state terraform'
    required: true

  terraform-provider-client-id:
    description: 'The client ID for your service principal, needed to authenticate to your tenant'
    required: true

  terraform-provider-client-secret:
    description: 'The client secret for your service principal, needed to authenticate to your tenant'
    required: true

  terraform-provider-subscription-id:
    description: 'The subscription id of the subscription you wish to deploy to, needed to authenticate to your tenant'
    required: true

  terraform-provider-tenant-id:
    description: 'The tenant id of which contains subscription you wish to deploy to, needed to authenticate to your tenant'
    required: true

  terraform-compliance-path:
    description: 'The path to your terraform-compliance policies, should be a local path or passed as git: etc'
    required: true

  checkov-skipped-tests:
    description: 'The CKV codes you wish to skip, if any.'
    required: true

  run-terraform-destroy:
    description: 'Do you want to run terraform destroy? - Set to true to trigger terraform plan -destroy'
    required: true
    default: "false"
    
  run-terraform-plan-only:
    description: 'Do you only want to run terraform plan & never run the apply or apply destroy? - Set to true to trigger terraform plan only.'
    required: true
    default: "true"
```

### Outputs

None
