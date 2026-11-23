variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "caribeshop"
}

variable "location" {
  description = "Región de Azure (ej. 'brazil south', 'eastus', 'eastus2')"
  type        = string
  default     = "brazil south"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "dev"
}

variable "admin_username" {
  description = "Usuario administrador de Linux"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Clave pública SSH para las instancias del VMSS (evita depender de archivo local en CI/CD)"
  type        = string
  default     = ""
}

variable "vm_size" {
  description = "Tamaño de las máquinas virtuales"
  type        = string
  default     = "Standard_D2s_v4"
}

variable "zones" {
  description = "Zonas de disponibilidad para el VMSS y Load Balancer"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "min_instances" {
  description = "Mínimo de instancias en el autoscale"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Máximo de instancias en el autoscale"
  type        = number
  default     = 3
}

variable "desired_instances" {
  description = "Instancias iniciales deseadas"
  type        = number
  default     = 2
}

variable "admin_ip" {
  description = "IP pública CIDR del operador para acceso administrativo al Key Vault (ej: 179.238.1.135/32)"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Correo electrónico para recibir notificaciones de alertas de Azure Monitor"
  type        = string
  default     = "admin@caribeshop.com"
}

variable "app_secret_value" {
  description = "Valor del secreto de la aplicación a almacenar en Key Vault"
  type        = string
  sensitive   = true
}
