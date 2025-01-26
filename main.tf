terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.16.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

// Existing resource group which the storage account lives in
data "azurerm_resource_group" "this" {
  name = "rg-${var.environment}-${var.location_short}-newworkspace"
}

// Existing log analytics workspace which the storage account sends logs to
data "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.environment}-${var.location_short}-newworkspace"
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_monitor_action_group" "this" {
  name                = "ag-${var.environment}-${var.location_short}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  short_name          = "ag-${var.environment}-${var.location_short}"

  email_receiver {
    name          = "Support"
    email_address = "help@support.com"
  }

}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "this" {
  name                = "${var.environment}-${var.location_short}-anonymous-access"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  evaluation_frequency = "PT5M" // Five minutes
  window_duration      = "PT5M" // Five minutes
  scopes               = [data.azurerm_log_analytics_workspace.this.id]
  severity             = 0
  criteria {
    query                   = <<-QUERY
      StorageBlogLogs
      | where AuthenticationType == "Anonymous"
      QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled          = false
  workspace_alerts_storage_enabled = false
  description                      = "Log alert that will trigger on anonymous access to blog storage"
  display_name                     = "Anonymous Access to Blog Storage"
  enabled                          = true
  skip_query_validation            = true


  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }
}
