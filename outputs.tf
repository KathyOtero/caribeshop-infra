output "resource_group_name" {
  description = "Nombre del grupo de recursos principal"
  value       = azurerm_resource_group.main.name
}

output "load_balancer_public_ip" {
  description = "IP pública asignada al Azure Load Balancer Standard"
  value       = azurerm_public_ip.lb.ip_address
}

output "website_url" {
  description = "URL principal para acceder a la aplicación CaribeShop"
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

output "health_check_url" {
  description = "URL para verificar la sonda de salud (Requisito E2)"
  value       = "http://${azurerm_public_ip.lb.ip_address}/health"
}

output "secret_verification_url" {
  description = "URL para demostrar la lectura del secreto con Managed Identity (Requisito S3)"
  value       = "http://${azurerm_public_ip.lb.ip_address}/secret"
}

output "key_vault_name" {
  description = "Nombre del Key Vault protegido con RBAC y firewall"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI del Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "vmss_name" {
  description = "Nombre del Virtual Machine Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.app.name
}

output "vmss_principal_id" {
  description = "Principal ID de la Identidad Administrada del VMSS (Requisito S4)"
  value       = azurerm_linux_virtual_machine_scale_set.app.identity[0].principal_id
}

output "log_analytics_workspace_id" {
  description = "ID del workspace de Log Analytics"
  value       = azurerm_log_analytics_workspace.main.id
}

output "kql_audit_query" {
  description = "Consulta KQL para Log Analytics requerida como evidencia en S6"
  value       = "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.KEYVAULT' | where OperationName == 'SecretGet' | project TimeGenerated, OperationName, CallerIPAddress, identity_claim_oid_g, requestUri_s"
}
