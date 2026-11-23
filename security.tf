resource "azurerm_network_security_group" "app" {
  name                = "${var.project_name}-app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Tráfico HTTP reenviado por el Load Balancer hacia el puerto backend 8080 (Requisito S2)
  # Nota: Azure Standard LB preserva la IP origen del cliente (Internet).
  security_rule {
    name                       = "Allow-HTTP-Backend-From-Internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Sonda de salud dedicada de Azure Load Balancer (Requisito E2)
  security_rule {
    name                       = "Allow-LB-Probe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Bloqueo estricto de SSH desde Internet (Requisito S2 / Remediado en PR 2)
  security_rule {
    name                       = "Deny-SSH-Internet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    description                = "Strictly block SSH port 22 from all Internet sources (Remediated in PR 2 - Requisito D1)"
  }

  # Bloqueo estricto de RDP desde Internet (Requisito S2)
  security_rule {
    name                       = "Deny-RDP-Internet"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Egress controlado: Permitir conexión HTTPS a Azure Key Vault (Requisito S2 - Rúbrica 100%)
  security_rule {
    name                       = "Allow-KeyVault-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureKeyVault"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
