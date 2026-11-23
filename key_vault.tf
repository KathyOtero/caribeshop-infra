resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  #checkov:skip=CKV2_AZURE_32:Using Service Endpoints and Network ACLs instead of Private Endpoints per project budget and rubric
  name                = "${var.project_name}-kv-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = "standard"

  # Habilitar autorización mediante RBAC (Requisito S3)
  rbac_authorization_enabled = true

  # Protección contra eliminación permanente (Requisito S3)
  purge_protection_enabled = true

  soft_delete_retention_days = 7

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    virtual_network_subnet_ids = [
      azurerm_subnet.app.id
    ]

    ip_rules = var.admin_ip != "" ? [var.admin_ip] : []
  }
}

# Asignación de rol de solo lectura de secretos para la identidad del VMSS (Requisito S4)
resource "azurerm_role_assignment" "vmss_secret_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.app.identity[0].principal_id
}

# Secreto con fecha de expiración (Requisito S3)
resource "azurerm_key_vault_secret" "app_secret" {
  name            = "app-secret"
  value           = var.app_secret_value
  content_type    = "text/plain"
  key_vault_id    = azurerm_key_vault.main.id
  expiration_date = "2027-11-22T00:00:00Z"

  depends_on = [
    azurerm_role_assignment.vmss_secret_reader
  ]
}
