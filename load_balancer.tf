resource "azurerm_public_ip" "lb" {
  name                = "${var.project_name}-public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  allocation_method = "Static"
  sku               = "Standard"

  zones = var.zones
}

resource "azurerm_lb" "main" {
  name                = "${var.project_name}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_lb_probe" "health" {
  name            = "health-probe"
  loadbalancer_id = azurerm_lb.main.id

  protocol     = "Http"
  port         = 8080
  request_path = "/health"
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.main.id
  frontend_ip_configuration_name = "frontend"

  protocol      = "Tcp"
  frontend_port = 80
  backend_port  = 8080

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.main.id
  ]

  probe_id = azurerm_lb_probe.health.id
}
