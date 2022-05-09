module "rg" {
  source = "registry.terraform.io/libre-devops/rg/azurerm"

  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-build" // rg-ldo-euw-dev-build
  location = local.location                                            // compares var.loc with the var.regions var to match a long-hand name, in this case, "euw", so "westeurope"
  tags     = local.tags

  #  lock_level = "CanNotDelete" // Do not set this value to skip lock
}

module "network" {
  source = "registry.terraform.io/libre-devops/network/azurerm"

  rg_name  = module.rg.rg_name // rg-ldo-euw-dev-build
  location = module.rg.rg_location
  tags     = local.tags

  vnet_name     = "vnet-${var.short}-${var.loc}-${terraform.workspace}-01" // vnet-ldo-euw-dev-01
  vnet_location = module.network.vnet_location

  address_space   = ["10.0.0.0/16"]
  subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_names    = ["sn1-${module.network.vnet_name}", "sn2-${module.network.vnet_name}", "sn3-${module.network.vnet_name}"] //sn1-vnet-ldo-euw-dev-01
  subnet_service_endpoints = {
    "sn1-${module.network.vnet_name}" = ["Microsoft.Storage", "Microsoft.EventHub"] // Adds extra subnet endpoints to sn1-vnet-ldo-euw-dev-01
    "sn2-${module.network.vnet_name}" = ["Microsoft.Storage", "Microsoft.Sql"],     // Adds extra subnet endpoints to sn2-vnet-ldo-euw-dev-01
    "sn3-${module.network.vnet_name}" = ["Microsoft.AzureActiveDirectory"]          // Adds extra subnet endpoints to sn3-vnet-ldo-euw-dev-01
  }
}

module "nsg" {
  source = "registry.terraform.io/libre-devops/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name  = "nsg-${element(keys(module.network.subnets_ids), 0)}" // nsg-sn1-vnet-ldo-euw-dev-01
  subnet_id = element(values(module.network.subnets_ids), 0)        // Adds NSG to all subnets
}

data "http" "user_ip" {
  url = "https://ipv4.icanhazip.com" // If running locally, running this block will fetch your outbound public IP of your home/office/ISP/VPN and add it.  It will add the hosted agent etc if running from Microsoft/GitLab
}

// This module does not consider for CMKs and allows the users to manually set bypasses
#checkov:skip=CKV2_AZURE_1:CMKs are not considered in this module
#checkov:skip=CKV2_AZURE_18:CMKs are not considered in this module
#checkov:skip=CKV_AZURE_33:Storage logging is not configured by default in this module
#tfsec:ignore:azure-storage-queue-services-logging-enabled tfsec:ignore:azure-storage-allow-microsoft-service-bypass #tfsec:ignore:azure-storage-default-action-deny
module "sa" {
  source = "registry.terraform.io/libre-devops/storage-account/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  storage_account_name            = "st${var.short}${var.loc}${terraform.workspace}01"
  access_tier                     = "Hot"
  identity_type                   = "SystemAssigned"
  allow_nested_items_to_be_public = true

  storage_account_properties = {

    // Set this block to enable network rules
    network_rules = {
      default_action = "Allow"
    }

    blob_properties = {
      versioning_enabled       = false
      change_feed_enabled      = false
      default_service_version  = "2020-06-12"
      last_access_time_enabled = false

      deletion_retention_policies = {
        days = 10
      }

      container_delete_retention_policy = {
        days = 10
      }
    }

    routing = {
      publish_internet_endpoints  = false
      publish_microsoft_endpoints = true
      choice                      = "MicrosoftRouting"
    }
  }
}

#tfsec:ignore:azure-storage-no-public-access
resource "azurerm_storage_container" "event_grid_blob" {
  name                  = "blob${var.short}${var.loc}${terraform.workspace}01"
  storage_account_name  = module.sa.sa_name
  container_access_type = "container"
}

module "event_hub_namespace" {
  source = "registry.terraform.io/libre-devops/event-hub-namespace/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  event_hub_namespace_name = "evhns-${var.short}-${var.loc}-${terraform.workspace}-01"
  identity_type            = "SystemAssigned"
  settings = {
    sku                  = "Standard"
    capacity             = 1
    auto_inflate_enabled = false
    zone_redundant       = false

    network_rulesets = {
      default_action                 = "Deny"
      trusted_service_access_enabled = true

      virtual_network_rule = {
        subnet_id                                       = element(values(module.network.subnets_ids), 0) // uses sn1
        ignore_missing_virtual_network_service_endpoint = false
      }
    }
  }
}

module "event_hub" {
  source = "registry.terraform.io/libre-devops/event-hub/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  event_hub_name     = "evh-${var.short}-${var.loc}-${terraform.workspace}-01"
  namespace_name     = module.event_hub_namespace.name
  storage_account_id = module.sa.sa_id

  settings = {

    status            = "Active"
    partition_count   = "1"
    message_retention = "1"

    capture_description = {
      enabled             = false
      encoding            = "Avro"
      interval_in_seconds = "60"
      size_limit_in_bytes = "10485760"
      skip_empty_archives = false

      destination = {
        name                = "EventHubArchive.AzureBlockBlob"
        archive_name_format = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"
        blob_container_name = azurerm_storage_container.event_grid_blob.name
      }
    }
  }
}

module "event_grid_system_topic" {
  source = "registry.terraform.io/libre-devops/eventgrid-system-topic/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  identity_type = "SystemAssigned"

  event_grid_name        = "evgst-${var.short}-${var.loc}-${terraform.workspace}-01"
  topic_type             = "Microsoft.Storage.StorageAccounts"
  source_arm_resource_id = module.sa.sa_id
}

module "event_grid_system_topic_subscription" {
  source = "registry.terraform.io/libre-devops/eventgrid-system-topic-event-subscription/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  event_subscription_name = "evgsub-${var.short}-${var.loc}-${terraform.workspace}-01"

  event_delivery_schema = "EventGridSchema"
  system_topic_name     = module.event_grid_system_topic.eventgrid_name
  eventhub_endpoint_id  = module.event_hub.id

  eventgrid_settings = {
    storage_blob_dead_letter_destination = {
      storage_account_id          = module.sa.sa_id
      storage_blob_container_name = azurerm_storage_container.event_grid_blob.name
    }
  }
}