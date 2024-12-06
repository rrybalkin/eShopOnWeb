
locals {
  key_vault_name = format("%s-kv", var.resource_name_prefix)
  container_registry_name = var.resource_name_prefix
  cosmosdb_account_name = var.resource_name_prefix
  sql_db_name = format("%s-db", var.resource_name_prefix)
  sql_db_server_name = format("%s-db-server", var.resource_name_prefix)
  service_bus_queue_name = "eshop-orders"
}

resource "azurerm_resource_group" "main" {
  location = var.primary_region
  name     = var.resource_group_name
}

###############################################################################
### Container Registry resources
###############################################################################
resource "azurerm_container_registry" "container_registry" {
  admin_enabled       = true
  location            = var.primary_region
  name                = local.container_registry_name
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  depends_on = [
    azurerm_resource_group.main,
  ]
}

resource "azurerm_container_registry_webhook" "container_registry_webhook" {
  actions             = ["push"]
  location            = var.primary_region
  name                = format("%sdeploy", var.eshop_publicapi_name)
  registry_name       = azurerm_container_registry.container_registry.name
  resource_group_name = azurerm_resource_group.main.name
  service_uri         = "https://${azurerm_linux_web_app.publicapi.site_credential.0.name}:${azurerm_linux_web_app.publicapi.site_credential.0.password}@${azurerm_linux_web_app.publicapi.name}.scm.azurewebsites.net/api/registry/webhook"
  depends_on = [
    azurerm_container_registry.container_registry,
  ]
}

###############################################################################
### Cosmos DB account resources
###############################################################################
resource "azurerm_cosmosdb_account" "main" {
  location            = "centralus"
  name                = local.cosmosdb_account_name
  offer_type          = "Standard"
  resource_group_name = azurerm_resource_group.main.name
  tags = {
    defaultExperience       = "Core (SQL)"
    hidden-cosmos-mmspecial = ""
  }
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    failover_priority = 0
    location          = "centralus"
  }
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_cosmosdb_sql_database" "cosmos_db_orders" {
  account_name        = azurerm_cosmosdb_account.main.name
  name                = "OrdersToDeliver"
  resource_group_name = azurerm_resource_group.main.name
  depends_on = [
    azurerm_cosmosdb_account.main,
  ]
}
resource "azurerm_cosmosdb_sql_container" "cosmos_db_orders_container" {
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = "OrdersToDeliver"
  name                  = "Items"
  partition_key_paths    = ["/orderId"]
  partition_key_version = 2
  resource_group_name   = azurerm_resource_group.main.name
  depends_on = [
    azurerm_cosmosdb_sql_database.cosmos_db_orders,
  ]
}
resource "azurerm_cosmosdb_sql_role_definition" "cosmos_db_role_data_reader" {
  account_name        = var.resource_name_prefix
  assignable_scopes   = [azurerm_cosmosdb_account.main.id]
  name                = "Cosmos DB Built-in Data Reader"
  resource_group_name = azurerm_resource_group.main.name
  type                = "BuiltInRole"
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata", 
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery", 
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read", 
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed"
    ]
  }
  depends_on = [
    azurerm_cosmosdb_account.main,
  ]
}
resource "azurerm_cosmosdb_sql_role_definition" "cosmos_db_role_data_contributor" {
  account_name        = var.resource_name_prefix
  assignable_scopes   = [azurerm_cosmosdb_account.main.id]
  name                = "Cosmos DB Built-in Data Contributor"
  resource_group_name = azurerm_resource_group.main.name
  type                = "BuiltInRole"
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*"
    ]
  }
  depends_on = [
    azurerm_cosmosdb_account.main,
  ]
}

###############################################################################
### Key Vault resources
###############################################################################
resource "azurerm_key_vault" "key_vault" {
  enable_rbac_authorization = true
  location                  = var.primary_region
  name                      = local.key_vault_name
  resource_group_name       = azurerm_resource_group.main.name
  sku_name                  = "standard"
  tenant_id                 = var.tenant_id
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_key_vault_secret" "vault_app_insights_conn_string" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "app-insight-connection-string"
  value        = azurerm_application_insights.function_app.connection_string
  depends_on = [
    azurerm_key_vault.key_vault,
  ]
}
resource "azurerm_key_vault_secret" "vault_cosmos_database_key" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cosmos-database-key"
  value        = azurerm_cosmosdb_account.main.primary_key
  depends_on = [
    azurerm_key_vault.key_vault,
  ]
}
resource "azurerm_key_vault_secret" "vault_order_items_delivery_func_url" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "order-items-delivery-processor-function-url"
  value        = "${azurerm_function_app_function.order_items_delivery_processor.invocation_url}?code=${data.azurerm_function_app_host_keys.function_app.primary_key}"
  depends_on = [
    azurerm_key_vault.key_vault,
  ]
}
resource "azurerm_key_vault_secret" "vault_service_bus_conn_string" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "service-bus-connection-string"
  value        = azurerm_servicebus_namespace.main.default_primary_connection_string
  depends_on = [
    azurerm_key_vault.key_vault,
  ]
}
resource "azurerm_key_vault_secret" "vault_sql_database_conn_string" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "sql-database-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.main.name}.database.windows.net,1433;Initial Catalog=${azurerm_mssql_database.main.name};Persist Security Info=False;User ID=${var.sql_db_admin_login};Password=${var.sql_db_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  depends_on = [
    azurerm_key_vault.key_vault,
  ]
}
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.my_object_id

  description          = "Key Vault Administrator role assigned to my user."
}
resource "azurerm_role_assignment" "publicapi" {
  scope                 = azurerm_key_vault.key_vault.id
  role_definition_name  = "Key Vault Secrets User"
  principal_id          = azurerm_linux_web_app.publicapi.identity[0].principal_id
}
resource "azurerm_role_assignment" "web" {
  scope                 = azurerm_key_vault.key_vault.id
  role_definition_name  = "Key Vault Secrets User"
  principal_id          = azurerm_windows_web_app.web.identity[0].principal_id
}
resource "azurerm_role_assignment" "web_replica" {
  count                 = var.enable_webapp_replica ? 1 : 0
  scope                 = azurerm_key_vault.key_vault.id
  role_definition_name  = "Key Vault Secrets User"
  principal_id          = azurerm_windows_web_app.web_replica[0].identity[0].principal_id
}
resource "azurerm_role_assignment" "functions" {
  scope                 = azurerm_key_vault.key_vault.id
  role_definition_name  = "Key Vault Secrets User"
  principal_id          = azurerm_windows_function_app.function_app.identity[0].principal_id
}

###############################################################################
### Logic App resources
###############################################################################
resource "azurerm_logic_app_workflow" "logic_app_fallback" {
  location = var.primary_region
  name     = "fallback-sending-email"
  parameters = {
    "$connections" = "{\"outlook\":{\"connectionId\":\"/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/connections/outlook\",\"connectionName\":\"outlook\",\"id\":\"/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${var.primary_region}/managedApis/outlook\"}}"
  }
  resource_group_name = azurerm_resource_group.main.name
  workflow_parameters = {
    "$connections" = "{\"defaultValue\":{},\"type\":\"Object\"}"
  }
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_logic_app_action_custom" "send_email_action" {
  body = jsonencode({
    inputs = {
      body = {
        Body       = "<p class=\"editor-paragraph\">Hey!<br><br>Please, check what is wrong with the order details:<br>@{triggerBody()}<br><br>In case if the order can not be processed automatically, this can be delivered manually. See the instruction <b><strong class=\"editor-text-bold\">here</strong></b>.<br><br><i><em class=\"editor-text-italic\">Thanks,<br>eShopOnWeb automation bot</em></i></p>"
        Importance = "Normal"
        Subject    = "There is a problem with eShopOnWeb order!\n"
        To         = var.my_external_email
      }
      host = {
        connection = {
          name = "@parameters('$connections')['outlook']['connectionId']"
        }
      }
      method = "post"
      path   = "/v2/Mail"
    }
    runAfter = {}
    type     = "ApiConnection"
  })
  logic_app_id = azurerm_logic_app_workflow.logic_app_fallback.id
  name         = "Send_an_email_(V2)"
  depends_on = [
    azurerm_logic_app_workflow.logic_app_fallback,
  ]
}
resource "azurerm_logic_app_trigger_http_request" "launch_trigger" {
  logic_app_id = azurerm_logic_app_workflow.logic_app_fallback.id
  method       = "POST"
  name         = "When_a_HTTP_request_is_received"
  schema       = jsonencode({})
  depends_on = [
    azurerm_logic_app_workflow.logic_app_fallback,
  ]
}
resource "azurerm_api_connection" "outlook" {
  managed_api_id      = "/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${var.primary_region}/managedApis/outlook"
  name                = "outlook"
  display_name        = "Outlook.com"
  resource_group_name = azurerm_resource_group.main.name
  depends_on = [
    azurerm_resource_group.main,
  ]
}

###############################################################################
### Service Bus resources
###############################################################################
resource "azurerm_servicebus_namespace" "main" {
  location            = var.primary_region
  name                = var.resource_name_prefix
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_servicebus_namespace_authorization_rule" "service_bus_namespace_auth_rule" {
  listen       = true
  manage       = true
  name         = "RootManageSharedAccessKey"
  namespace_id = azurerm_servicebus_namespace.main.id
  send         = true
}
resource "azurerm_servicebus_queue" "service_bus_queue_orders" {
  name         = local.service_bus_queue_name
  namespace_id = azurerm_servicebus_namespace.main.id
}

###############################################################################
### SQL database and server resources
###############################################################################
resource "azurerm_mssql_server" "main" {
  administrator_login = var.sql_db_admin_login
  administrator_login_password = var.sql_db_admin_password
  location            = var.sql_db_region
  name                = format("%s-db-server", var.resource_name_prefix)
  resource_group_name = azurerm_resource_group.main.name
  version             = "12.0"
  azuread_administrator {
    login_username = var.my_username
    object_id      = var.my_object_id
  }
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_mssql_database" "main" {
  name                 = format("%s-db", var.resource_name_prefix)
  server_id            = azurerm_mssql_server.main.id
  storage_account_type = "Local"
  depends_on = [
    azurerm_mssql_server.main,
  ]
}
resource "azurerm_mssql_database_extended_auditing_policy" "sql_db_auditing_policy" {
  database_id            = azurerm_mssql_database.main.id
  enabled                = false
  log_monitoring_enabled = false
  depends_on = [
    azurerm_mssql_database.main,
  ]
}
resource "azurerm_mssql_database_extended_auditing_policy" "sql_db_auditing_policy_master" {
  database_id            = "${azurerm_mssql_server.main.id}/databases/master"
  enabled                = false
  log_monitoring_enabled = false
}
resource "azurerm_mssql_server_microsoft_support_auditing_policy" "sql_db_server_support_policy_master" {
  enabled                = false
  log_monitoring_enabled = false
  server_id              = azurerm_mssql_server.main.id
  depends_on = [
    azurerm_mssql_server.main,
  ]
}
resource "azurerm_mssql_server_transparent_data_encryption" "sql_db_server_encryption" {
  server_id = azurerm_mssql_server.main.id
  depends_on = [
    azurerm_mssql_server.main,
  ]
}
resource "azurerm_mssql_server_extended_auditing_policy" "sql_db_server_auditing_policy" {
  enabled                = false
  log_monitoring_enabled = false
  server_id              = azurerm_mssql_server.main.id
  depends_on = [
    azurerm_mssql_server.main,
  ]
}
resource "azurerm_mssql_firewall_rule" "sql_db_firewall_rule_azure_ips" {
  end_ip_address   = "0.0.0.0"
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  depends_on = [
    azurerm_mssql_server.main,
  ]
}
resource "azurerm_mssql_server_security_alert_policy" "sql_db_server_security_alert_policy" {
  resource_group_name = azurerm_resource_group.main.name
  server_name         = format("%s-db-server", var.resource_name_prefix)
  state               = "Disabled"
  depends_on = [
    azurerm_mssql_server.main,
  ]
}

###############################################################################
### Storage account resources
###############################################################################
resource "azurerm_storage_account" "function_app" {
  account_kind                     = "Storage"
  account_replication_type         = "LRS"
  account_tier                     = "Standard"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  default_to_oauth_authentication  = true
  location                         = var.primary_region
  name                             = format("%sfa", var.resource_name_prefix)
  resource_group_name              = azurerm_resource_group.main.name
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_storage_container" "functioncode" {
  name                 = "functioncode"
  storage_account_id  = azurerm_storage_account.function_app.id
}
resource "azurerm_storage_container" "eshop_orders" {
  name                 = "eshop-orders"
  storage_account_id  = azurerm_storage_account.function_app.id
}
resource "azurerm_storage_share" "function_app" {
  name                 = format("%s-fa9d8f", var.resource_name_prefix)
  quota                = 102400
  storage_account_id  = azurerm_storage_account.function_app.id
}
resource "azurerm_storage_table" "function_app" {
  name                 = "AzureFunctionsDiagnosticEvents202412"
  storage_account_name = azurerm_storage_account.function_app.name
}

###############################################################################
### eSHOP Public API Web App resources
###############################################################################
resource "azurerm_service_plan" "publicapi" {
  location            = var.primary_region
  name                = format("%s-sp", var.eshop_publicapi_name)
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.eshop_publicapi_sku
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_linux_web_app" "publicapi" {
  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING                    = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=app-insight-connection-string)"
    ASPNETCORE_ENVIRONMENT                                   = "Development"
    ASPNETCORE_URLS                                          = "http://+:80"
    ApplicationInsightsAgent_EXTENSION_VERSION               = "~3"
    ConnectionStrings__APPLICATIONINSIGHTS_CONNECTION_STRING = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=app-insight-connection-string)"
    ConnectionStrings__CatalogConnection                     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    ConnectionStrings__IdentityConnection                    = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    DOCKER_ENABLE_CI                                         = "true"
    UseOnlyInMemoryDatabase                                  = "False"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE                      = "false"
    XDT_MicrosoftApplicationInsights_Mode                    = "Recommended"
  }
  ftp_publish_basic_authentication_enabled = false
  https_only                               = true
  location                                 = var.primary_region
  name                                     = var.eshop_publicapi_name
  resource_group_name                      = azurerm_resource_group.main.name
  service_plan_id                          = azurerm_service_plan.publicapi.id
  identity {
    type = "SystemAssigned"
  }
  site_config {
    always_on                         = false
    ftps_state                        = "FtpsOnly"
    ip_restriction_default_action     = var.ip_restriction_default_action
    scm_ip_restriction_default_action = var.scm_ip_restriction_default_action
  }
  depends_on = [
    azurerm_service_plan.publicapi,
  ]
}
resource "azurerm_app_service_custom_hostname_binding" "publicapi" {
  app_service_name    = var.eshop_publicapi_name
  hostname            = azurerm_linux_web_app.publicapi.default_hostname // format("%s.azurewebsites.net", var.eshop_publicapi_name)
  resource_group_name = azurerm_resource_group.main.name
  depends_on = [
    azurerm_linux_web_app.publicapi,
  ]
}

###############################################################################
### eSHOP WEB main web app resources (app, staging slot, autoscaling)
###############################################################################
resource "azurerm_service_plan" "web" {
  location            = var.primary_region
  name                = format("%s-sp", var.eshop_webapp_name)
  os_type             = "Windows"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.eshop_webapp_sku
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_windows_web_app" "web" {
  app_settings = {
    ASPNETCORE_ENVIRONMENT                                   = "Development"
    ConnectionStrings__APPLICATIONINSIGHTS_CONNECTION_STRING = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=app-insight-connection-string)"
    ConnectionStrings__CatalogConnection                     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    ConnectionStrings__IdentityConnection                    = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    ORDER_ITEMS_DELIVERY_PROCESSOR_URL                       = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=order-items-delivery-processor-function-url)"
    SERVICE_BUS_CONNECTION_STRING                            = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=service-bus-connection-string)"
    UseOnlyInMemoryDatabase                                  = "False"
  }
  client_affinity_enabled = true
  https_only              = true
  location                = var.primary_region
  name                    = var.eshop_webapp_name
  resource_group_name     = azurerm_resource_group.main.name
  service_plan_id         = azurerm_service_plan.web.id
  identity {
    type = "SystemAssigned"
  }
  logs {
    application_logs {
      file_system_level = "Verbose"
    }
  }
  site_config {
    always_on                         = false
    ftps_state                        = "FtpsOnly"
    ip_restriction_default_action     = var.ip_restriction_default_action
    scm_ip_restriction_default_action = var.scm_ip_restriction_default_action
    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
    }
  }
  depends_on = [
    azurerm_service_plan.web,
  ]
}
resource "azurerm_app_service_custom_hostname_binding" "web" {
  app_service_name    = azurerm_windows_web_app.web.name
  hostname            = azurerm_windows_web_app.web.default_hostname
  resource_group_name = azurerm_resource_group.main.name
  depends_on = [
    azurerm_windows_web_app.web,
  ]
}
resource "azurerm_windows_web_app_slot" "web_staging" {
  count               = var.enable_staging_slot ? 1 : 0
  name                = "staging"
  app_service_id      = azurerm_windows_web_app.web.id

  app_settings = {
    ASPNETCORE_ENVIRONMENT                                   = "Development"
    ConnectionStrings__APPLICATIONINSIGHTS_CONNECTION_STRING = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=app-insight-connection-string)"
    ConnectionStrings__CatalogConnection                     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    ConnectionStrings__IdentityConnection                    = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    ORDER_ITEMS_DELIVERY_PROCESSOR_URL                       = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=order-items-delivery-processor-function-url)"
    SERVICE_BUS_CONNECTION_STRING                            = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=service-bus-connection-string)"
    UseOnlyInMemoryDatabase                                  = "False"
  }
  client_affinity_enabled = true
  https_only              = true
  site_config {
    always_on                         = false
    ftps_state                        = "FtpsOnly"
    ip_restriction_default_action     = var.ip_restriction_default_action
    scm_ip_restriction_default_action = var.scm_ip_restriction_default_action
    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
    }
  }
}
resource "azurerm_monitor_autoscale_setting" "webapp_autoscale" {
  count               = var.enable_web_autoscale ? 1 : 0
  name                = "${azurerm_windows_web_app.web.name}-autoscale"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.web.id

  profile {
    name = "autoProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.web_autoscale_cpu_threshold
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.web_autoscale_cpu_threshold
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

###############################################################################
### eSHOP WEB replica web app resources
###############################################################################
resource "azurerm_service_plan" "web_replica" {
  count               = var.enable_webapp_replica ? 1 : 0
  location            = var.secondary_region
  name                = format("%s-replica-sp", var.eshop_webapp_name)
  os_type             = "Windows"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.eshop_webapp_replica_sku
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_windows_web_app" "web_replica" {
  count               = var.enable_webapp_replica ? 1 : 0
  app_settings = {
    ASPNETCORE_ENVIRONMENT                                   = "Development"
    ConnectionStrings__APPLICATIONINSIGHTS_CONNECTION_STRING = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=app-insight-connection-string)"
    ConnectionStrings__CatalogConnection                     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    ConnectionStrings__IdentityConnection                    = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=sql-database-connection-string)"
    ORDER_ITEMS_DELIVERY_PROCESSOR_URL                       = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=order-items-delivery-processor-function-url)"
    SERVICE_BUS_CONNECTION_STRING                            = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=service-bus-connection-string)"
    UseOnlyInMemoryDatabase                                  = "False"
  }
  client_affinity_enabled = true
  https_only              = true
  location                = var.secondary_region
  name                    = "${var.eshop_webapp_name}-replica"
  resource_group_name     = azurerm_resource_group.main.name
  service_plan_id         = azurerm_service_plan.web_replica[0].id
  identity {
    type = "SystemAssigned"
  }
  logs {
    application_logs {
      file_system_level = "Verbose"
    }
  }
  site_config {
    always_on                         = false
    ftps_state                        = "FtpsOnly"
    ip_restriction_default_action     = var.ip_restriction_default_action
    scm_ip_restriction_default_action = var.scm_ip_restriction_default_action
    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
    }
  }
  depends_on = [
    azurerm_service_plan.web_replica[0],
  ]
}
resource "azurerm_app_service_custom_hostname_binding" "web_replica" {
  app_service_name    = "${var.eshop_webapp_name}-replica"
  hostname            = format("${var.eshop_webapp_name}-replica.azurewebsites.net")
  resource_group_name = azurerm_resource_group.main.name
}

###############################################################################
### Traffic manager resources
###############################################################################
resource "azurerm_traffic_manager_profile" "geo_profile" {
  count               = var.enable_traffic_manager ? 1 : 0
  name                = "${var.resource_name_prefix}-tm"
  resource_group_name = azurerm_resource_group.main.name
  traffic_routing_method = "Geographic"

  dns_config {
    relative_name = var.eshop_webapp_name
    ttl           = 60
  }

  monitor_config {
    protocol = "HTTPS"
    port     = 443
    path     = "/"
  }
}
resource "azurerm_traffic_manager_azure_endpoint" "primary" {
  count               = var.enable_traffic_manager ? 1 : 0
  name                = "primary-endpoint"
  profile_id          = azurerm_traffic_manager_profile.geo_profile[0].id
  target_resource_id  = azurerm_windows_web_app.web.id

  geo_mappings = ["GEO-NA"] // North America / Central America / Caribbean
}
resource "azurerm_traffic_manager_azure_endpoint" "secondary" {
  count               = var.enable_traffic_manager && var.enable_webapp_replica ? 1 : 0
  name                = "secondary-endpoint"
  profile_id          = azurerm_traffic_manager_profile.geo_profile[0].id
  target_resource_id  = azurerm_windows_web_app.web_replica[0].id

  geo_mappings = ["GEO-EU", "GEO-ME"] // Define Europe and Middle East regions for secondary mapping
}

###############################################################################
### Function App with 2 eShop functions resources
###############################################################################
# resource "null_resource" "build_functions_zip" {
#   provisioner "local-exec" {
#     command     = "./build_functions.sh"
#     interpreter = ["bash"]
#   }
#   # uncomment when need to rebuild zip with functions code
# #   triggers = {
# #     always_run = timestamp()
# #   }
# }
# resource "azurerm_storage_blob" "functions_zip" {
#   name                   = "${var.resource_name_prefix}-functions.zip"
#   storage_account_name   = azurerm_storage_account.function_app.name
#   storage_container_name = azurerm_storage_container.functioncode.name
#   type                   = "Block"
#   source                 = "./functions-1.0.zip"
#   depends_on = [null_resource.build_functions_zip]
# }
# data "azurerm_storage_account_sas" "functions_app" {
#   connection_string = azurerm_storage_account.function_app.primary_connection_string
#   https_only        = true
#   start             = formatdate("YYYY-MM-DD'T'hh:mm'Z'", timeadd(timestamp(), "-1h"))
#   expiry            = formatdate("YYYY-MM-DD'T'hh:mm'Z'", timeadd(timestamp(), "720h"))
#
#   resource_types {
#     service   = true
#     container = false
#     object    = true
#   }
#
#   services {
#     blob  = true
#     queue = false
#     table = false
#     file  = false
#   }
#
#   permissions {
#     read    = true
#     write   = false
#     delete  = false
#     list    = false
#     add     = false
#     create  = false
#     update  = false
#     process = false
#     filter  = false
#     tag     = false
#   }
# }

resource "azurerm_service_plan" "function_app" {
  location            = var.primary_region
  name                = "${var.resource_name_prefix}-functions-sp"
  os_type             = "Windows"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Y1"
  depends_on = [
    azurerm_resource_group.main,
  ]
}
# Need to run NPM install command after creating the app (via Azure Portal -> Dev Tools -> Console):
# > npm install @azure/cosmos @azure/storage-blob axios uuidv4
resource "azurerm_windows_function_app" "function_app" {
  app_settings = {
    COSMOS_DB_ENDPOINT                                       = azurerm_cosmosdb_account.main.endpoint
    COSMOS_DB_KEY                                            = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=cosmos-database-key)"
    FallbackWebhookUrl                                       = azurerm_logic_app_trigger_http_request.launch_trigger.callback_url
    cloudxfinaltaskdemo_RootManageSharedAccessKey_SERVICEBUS = azurerm_servicebus_namespace.main.default_primary_connection_string
    FUNCTIONS_WORKER_RUNTIME                                 = "node"
    // WEBSITE_RUN_FROM_PACKAGE                                 = "https://${azurerm_storage_account.function_app.name}.blob.core.windows.net/${azurerm_storage_container.functioncode.name}/${azurerm_storage_blob.functions_zip.name}${data.azurerm_storage_account_sas.functions_app.sas}"
  }
  location                                 = var.primary_region
  name                                     = format("%s-fa", var.resource_name_prefix)
  resource_group_name                      = azurerm_resource_group.main.name
  service_plan_id                          = azurerm_service_plan.function_app.id
  storage_account_access_key               = azurerm_storage_account.function_app.primary_access_key
  storage_account_name                     = azurerm_storage_account.function_app.name
  identity {
    type = "SystemAssigned"
  }
  site_config {
    application_insights_connection_string = azurerm_application_insights.function_app.connection_string
    ip_restriction_default_action     = var.ip_restriction_default_action
    scm_ip_restriction_default_action = var.scm_ip_restriction_default_action
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
    application_stack {
      dotnet_version      = null # Nullify other runtimes
      node_version        = "~20"
    }
  }
  tags = {
    "hidden-link: /app-insights-conn-string" = azurerm_application_insights.function_app.connection_string
    "hidden-link: /app-insights-instrumentation-key" = azurerm_application_insights.function_app.instrumentation_key
  }
  depends_on = [
    azurerm_service_plan.function_app,
  ]
}
resource "azurerm_function_app_function" "order_items_async_reserver" {
  config_json = jsonencode({
    bindings = [{
      connection = "cloudxfinaltaskdemo_RootManageSharedAccessKey_SERVICEBUS"
      direction  = "in"
      name       = "mySbMsg"
      queueName  = local.service_bus_queue_name
      type       = "serviceBusTrigger"
    }]
  })
  function_app_id = azurerm_windows_function_app.function_app.id
  name            = "OrderItemsAsyncReserver"
  test_data       = "Service Bus Message"
  # a kind of bug in Azure, uncomment/comment helps to create this function with code
#   file {
#     name = "index.js"
#     content = file("functions/src/OrderAsyncReserver/index.js")
#   }
  depends_on = [
    azurerm_windows_function_app.function_app,
  ]
}
resource "azurerm_function_app_function" "order_items_delivery_processor" {
  config_json = jsonencode({
    bindings = [{
      authLevel = "admin"
      direction = "in"
      methods   = ["post"]
      name      = "req"
      type      = "httpTrigger"
      }, {
      direction = "out"
      name      = "res"
      type      = "http"
    }]
  })

  function_app_id = azurerm_windows_function_app.function_app.id
  language        = "Javascript"
  name            = "OrderItemsDeliveryProcessor"
  test_data = jsonencode({
    name = "Azure"
  })
  # a kind of bug in Azure, uncomment/comment helps to create this function with code
#   file {
#     name = "index.js"
#     content = file("functions/src/OrderDeliveryProcessor/index.js")
#   }
  depends_on = [
    azurerm_windows_function_app.function_app,
  ]
}
data "azurerm_function_app_host_keys" "function_app" {
  name = azurerm_windows_function_app.function_app.name
  resource_group_name = azurerm_resource_group.main.name

  depends_on = [
    azurerm_windows_function_app.function_app,
    azurerm_function_app_function.order_items_async_reserver,
    azurerm_function_app_function.order_items_delivery_processor
  ]
}
resource "azurerm_app_service_custom_hostname_binding" "function_app" {
  app_service_name    = format("%s-fa", var.resource_name_prefix)
  hostname            = azurerm_windows_function_app.function_app.default_hostname
  resource_group_name = azurerm_resource_group.main.name
  depends_on = [
    azurerm_windows_function_app.function_app,
  ]
}

###############################################################################
### Application Insights resources
###############################################################################
resource "azurerm_monitor_action_group" "app_insights_smart_detection" {
  name                = "Application Insights Smart Detection"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "SmartDetect"
  arm_role_receiver {
    name                    = "Monitoring Contributor"
    role_id                 = "749f88d5-cbae-40b8-bcfc-e573ddc772fa"
    use_common_alert_schema = true
  }
  arm_role_receiver {
    name                    = "Monitoring Reader"
    role_id                 = "43d0d8ad-25c7-4714-9337-8ba259a9fe05"
    use_common_alert_schema = true
  }
  depends_on = [
    azurerm_resource_group.main,
  ]
}
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.resource_name_prefix}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
resource "azurerm_application_insights" "function_app" {
  application_type    = "web"
  location            = var.primary_region
  name                = format("%s-app-insights", var.resource_name_prefix)
  resource_group_name = azurerm_resource_group.main.name
  sampling_percentage = 0
  workspace_id        = azurerm_log_analytics_workspace.logs.id
  depends_on = [
    azurerm_resource_group.main,
  ]
}
