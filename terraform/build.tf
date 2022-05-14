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
    "sn1-${module.network.vnet_name}" = ["Microsoft.Storage"]                   // Adds extra subnet endpoints to sn1-vnet-ldo-euw-dev-01
    "sn2-${module.network.vnet_name}" = ["Microsoft.Storage", "Microsoft.Sql"], // Adds extra subnet endpoints to sn2-vnet-ldo-euw-dev-01
    "sn3-${module.network.vnet_name}" = ["Microsoft.AzureActiveDirectory"]      // Adds extra subnet endpoints to sn3-vnet-ldo-euw-dev-01
  }
}

module "acr" {
  source = "registry.terraform.io/libre-devops/azure-container-registry/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  acr_name      = "acr${var.short}${var.loc}${terraform.workspace}01"
  sku           = "Standard"
  identity_type = "SystemAssigned"
  admin_enabled = true

  settings = {
    network_rule_set = {
      virtual_network = {
        action    = "Allow"
        subnet_id = element(values(module.network.subnets_ids), 0)
      }
    }
  }
}

module "rt" {
  source = "registry.terraform.io/libre-devops/route-table/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  route_table_name              = "rt-${var.short}-${var.loc}-${terraform.workspace}-01"
  enable_force_tunneling        = true
  force_tunnel_route_name       = "udr-${var.short}-${var.loc}-${terraform.workspace}-ForceInternetTunnel"
  disable_bgp_route_propagation = true

  associate_with_subnet  = true
  subnet_id_to_associate = element(values(module.network.subnets_ids), 0)
}
