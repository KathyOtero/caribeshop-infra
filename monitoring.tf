resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku               = "PerGB2018"
  retention_in_days = 30
}

# Configuración de diagnóstico de Key Vault hacia Log Analytics (Requisito S6)
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "key-vault-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }
}

# Grupo de acción para notificaciones por correo (Requisito E5)
resource "azurerm_monitor_action_group" "email" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "carishop"

  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }
}

# Alerta de métrica de CPU sostenida en el VMSS (Requisito E5)
resource "azurerm_monitor_metric_alert" "cpu" {
  name                = "${var.project_name}-cpu-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine_scale_set.app.id]

  description = "CPU sostenida alta en CaribeShop (> 80%)"
  severity    = 2
  frequency   = "PT1M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}
