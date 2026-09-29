module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "swedencentral"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "storage" {
  source  = "codectl/sa/azure"
  version = "~> 1.0"

  storage = {
    name                = module.naming.storage_account.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"


  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.18.0.0/16"]

    subnets = {
      sn1 = {
        address_prefixes       = ["10.18.1.0/24"]
        network_security_group = {}
        delegations = {
          web = {
            name = "Microsoft.Web/serverFarms"
            actions = [
              "Microsoft.Network/virtualNetworks/subnets/action"
            ]
          }
        }
      }
    }
  }
}

module "service_plan" {
  source  = "codectl/plan/azure"
  version = "~> 1.0"

  plans = {
    plan1 = {
      name                = module.naming.app_service_plan.name
      resource_group_name = module.rg.groups.demo.name
      location            = module.rg.groups.demo.location
      os_type             = "Linux"
      sku_name            = "P1v2"
      reserved            = true
    }
  }
}

module "function_app" {
  source  = "codectl/func/azure"
  version = "~> 1.0"

  resource_group_name = module.rg.groups.demo.name
  location            = module.rg.groups.demo.location

  function_app = {
    type                          = "linux"
    name                          = module.naming.function_app.name_unique
    storage_account_name          = module.storage.account.name
    storage_account_access_key    = module.storage.account.primary_access_key
    service_plan_id               = module.service_plan.plans.plan1.id
    virtual_network_subnet_id     = module.network.subnets.sn1.id
    public_network_access_enabled = false

    site_config = {
    }
  }
}
