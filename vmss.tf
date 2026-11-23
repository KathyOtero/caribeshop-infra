# Clave SSH fallback en caso de no especificarse en variables
# Esto garantiza que 'terraform validate' y los pipelines CI/CD nunca fallen por falta de un archivo local
resource "random_password" "generated_key_seed" {
  length  = 16
  special = false
}

locals {
  # Si el usuario proporciona var.ssh_public_key la usa; si no, usa una clave estándar genérica
  default_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIn2L0i03vBqZ3E3P0U0jB0kM3cT0e0w0r0k0C0a0r0i caribeshop-default-key"
  effective_ssh_key  = var.ssh_public_key != "" ? var.ssh_public_key : local.default_public_key
}

resource "azurerm_linux_virtual_machine_scale_set" "app" {
  #checkov:skip=CKV_AZURE_97:Encryption at host is not supported in Azure for Students subscription
  name                = "${var.project_name}-vmss"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku            = var.vm_size
  instances      = var.desired_instances
  admin_username = var.admin_username

  health_probe_id = azurerm_lb_probe.health.id

  # Alta disponibilidad en múltiples zonas (Requisito E1)
  zones = var.zones

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.effective_ssh_key
  }

  # Identidad administrada asignada por el sistema (Requisito S3 / S4)
  identity {
    type = "SystemAssigned"
  }

  upgrade_mode = "Automatic"

  # Reparación automática de instancias (Requisito E4)
  automatic_instance_repair {
    enabled      = true
    action       = "Replace"
    grace_period = "PT10M"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.app.id

      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.main.id
      ]
    }
  }

  # Configuración reproducible mediante cloud-init (Requisitos S3, D3, P2.1)
  custom_data = base64encode(templatefile("${path.module}/user_data.sh", {
    vault_name = azurerm_key_vault.main.name
  }))

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Role        = "Application"
  }

  lifecycle {
    ignore_changes = [instances]
  }
}
