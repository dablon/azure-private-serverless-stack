# ============================================
# OUTPUTS
# ============================================

output "resource_group" {
  description = "Nombre del grupo de recursos"
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Nombre de la Azure Function"
  value       = azurerm_windows_function_app.main.name
}

output "function_app_url" {
  description = "URL de la Azure Function"
  value       = azurerm_windows_function_app.main.default_hostname
}

output "eventgrid_topic_name" {
  description = "Nombre del Event Grid Topic"
  value       = azurerm_eventgrid_topic.main.name
}

output "eventgrid_topic_endpoint" {
  description = "Endpoint del Event Grid Topic"
  value       = azurerm_eventgrid_topic.main.endpoint
}

output "vnet_name" {
  description = "Nombre de la Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "private_endpoint_function_id" {
  description = "ID del Private Endpoint de Function"
  value       = azurerm_private_endpoint.function.id
}

output "private_endpoint_eventgrid_id" {
  description = "ID del Private Endpoint de Event Grid"
  value       = azurerm_private_endpoint.eventgrid.id
}

output "storage_account_name" {
  description = "Nombre de la Storage Account"
  value       = azurerm_storage_account.main.name
}
