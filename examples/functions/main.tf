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
      os_type             = "Linux"
      sku_name            = "EP1"
      kind                = "functionapp"
    }
  }
}

module "function_app" {
  source  = "codectl/func/azure"
  version = "~> 1.0"

  function_app = {
    type                       = "linux"
    name                       = module.naming.function_app.name_unique
    resource_group_name        = module.rg.groups.demo.name
    location                   = module.rg.groups.demo.location
    storage_account_name       = module.storage.account.name
    storage_account_access_key = module.storage.account.primary_access_key
    service_plan_id            = module.service_plan.plans.plan1.id

    app_settings = {
      FUNCTIONS_WORKER_RUNTIME = "node"
    }

    site_config = {
      application_stack = {
        node_version = "22"
      }
    }

    functions = {
      http-trigger = {
        name     = "HttpTrigger"
        language = "Javascript"
        config_json = jsonencode({
          bindings = [
            {
              authLevel = "function"
              direction = "in"
              methods   = ["get", "post"]
              name      = "req"
              type      = "httpTrigger"
            },
            {
              direction = "out"
              name      = "$return"
              type      = "http"
            }
          ]
        })

        files = {
          index = {
            name    = "index.js"
            content = <<-EOT
            module.exports = async function (context, req) {
              context.res = {
                body: "Hello from codectl"
              };
            };
            EOT
          }
        }
      }
    }
  }
}
