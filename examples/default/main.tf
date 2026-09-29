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

module "service_plan" {
  source  = "codectl/plan/azure"
  version = "~> 1.0"

  plans = {
    plan1 = {
      name                = module.naming.app_service_plan.name
      resource_group_name = module.rg.groups.demo.name
      location            = module.rg.groups.demo.location
      os_type             = "Windows"
      sku_name            = "B1"
    }
  }
}

module "identity" {
  source  = "codectl/uai/azure"
  version = "~> 1.0"

  identity = {
    name                = module.naming.user_assigned_identity.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
  }
}

module "function_app" {
  source  = "codectl/func/azure"
  version = "~> 1.0"

  resource_group_name = module.rg.groups.demo.name
  location            = module.rg.groups.demo.location

  function_app = {
    type                       = "windows"
    name                       = module.naming.function_app.name_unique
    location                   = module.rg.groups.demo.location
    storage_account_name       = module.storage.account.name
    storage_account_access_key = module.storage.account.primary_access_key
    service_plan_id            = module.service_plan.plans.plan1.id
    app_settings = {
      "WEBSITE_RUN_FROM_PACKAGE"        = "1"
      "WEBSITE_ENABLE_SYNC_UPDATE_SITE" = "true"
      "FUNCTIONS_WORKER_RUNTIME"        = "dotnet-isolated"
    }
    site_config = {
      always_on              = true
      http2_enabled          = false
      vnet_route_all_enabled = true
      application_stack = {
        use_dotnet_isolated_runtime = true
        dotnet_version              = "v8.0"
      }
    }

    identity = {
      type         = "UserAssigned"
      identity_ids = [module.identity.identity.id]
    }
  }
}
