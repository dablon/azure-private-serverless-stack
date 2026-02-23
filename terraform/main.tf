# ============================================
# RESOURCE GROUP
# ============================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = var.tags
}

# ============================================
# VIRTUAL NETWORK & SUBNETS
# ============================================

resource "azurerm_virtual_network" "main" {
  name                = "vnet-serverless-${var.environment}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = var.tags
}

resource "azurerm_subnet" "function" {
  name                 = "snet-function-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.function_subnet_cidr]
  
  delegation {
    name = "Microsoft.App.environments"
    
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "eventgrid" {
  name                 = "snet-eventgrid-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.eventgrid_subnet_cidr]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
  
  private_endpoint_network_policies_enabled = true
}

# ============================================
# STORAGE ACCOUNT
# ============================================

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                     = "stfunc${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.function.id, azurerm_subnet.private_endpoints.id]
  }
  
  tags = var.tags
}

# ============================================
# APP SERVICE PLAN (PREMIUM)
# ============================================

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Windows"
  sku_name            = var.function_sku
  
  tags = var.tags
}

# ============================================
# AZURE FUNCTION
# ============================================

resource "azurerm_windows_function_app" "main" {
  name                = "func-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  
  service_plan_id = azurerm_service_plan.main.id
  
  identity {
    type = "SystemAssigned"
  }
  
  site_config {
    always_on = true
    http2_enabled = true
    
    application_stack {
      dotnet_version = "8"
    }
  }
  
  tags = var.tags
}

# ============================================
# VNET INTEGRATION FOR FUNCTION
# ============================================

resource "azurerm_app_service_virtual_network_swift_connection" "function_vnet" {
  app_service_id = azurerm_windows_function_app.main.id
  subnet_id     = azurerm_subnet.function.id
}

# ============================================
# EVENT GRID TOPIC
# ============================================

resource "azurerm_eventgrid_topic" "main" {
  name                = "egt-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  input_schema = "CloudEventSchemaV1_0"
  
  tags = var.tags
}

# ============================================
# PRIVATE DNS ZONES
# ============================================

resource "azurerm_private_dns_zone" "function" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.main.name
  
  tags = var.tags
}

resource "azurerm_private_dns_zone" "eventgrid" {
  name                = "privatelink.eventgrid.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  
  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "function" {
  name                  = "dns-link-function-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.function.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "eventgrid" {
  name                  = "dns-link-eventgrid-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.eventgrid.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# ============================================
# PRIVATE ENDPOINTS
# ============================================

# Private Endpoint para Azure Function
resource "azurerm_private_endpoint" "function" {
  name                = "pe-function-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  
  private_service_connection {
    name                           = "pe-function-connection"
    private_connection_resource_id = azurerm_windows_function_app.main.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }
  
  private_dns_zone_group {
    name                 = "function-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.function.id]
  }
}

# Private Endpoint para Event Grid Topic
resource "azurerm_private_endpoint" "eventgrid" {
  name                = "pe-eventgrid-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  
  private_service_connection {
    name                           = "pe-eventgrid-connection"
    private_connection_resource_id = azurerm_eventgrid_topic.main.id
    is_manual_connection           = false
    subresource_names              = ["topic"]
  }
  
  private_dns_zone_group {
    name                 = "eventgrid-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.eventgrid.id]
  }
}

# ============================================
# EVENT SUBSCRIPTION
# ============================================

resource "azurerm_eventgrid_event_subscription" "function" {
  name  = "sub-function-${var.environment}"
  scope = azurerm_eventgrid_topic.main.id
  
  webhook_endpoint {
    url = "${azurerm_windows_function_app.main.default_hostname}/runtime/webhooks/eventgrid?functionName=EventGridTrigger"
  }
  
  delivery_identity {
    type = "SystemAssigned"
  }
  
  delivery_property {
    header_name = "aeg-subscription-name"
  }
}
