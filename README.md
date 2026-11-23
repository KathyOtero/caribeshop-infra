# CaribeShop — Infraestructura Segura, Escalable y de Alta Disponibilidad en Azure

Este repositorio contiene la definición como código (IaC) en **Terraform** de la plataforma en la nube para **CaribeShop**, desarrollada para el Taller Integrador de *Infraestructura para TI* (Universidad Tecnológica de Bolívar).

---

## 1. Arquitectura de la Solución

```text
                                     INTERNET
                                        │
                         [IP Pública Standard Redundante]
                                        │
                           [Azure Load Balancer Standard]
                                        │ (Sonda /health en TCP 8080)
      ┌─────────────────────────────────┴─────────────────────────────────┐
      │                      Subred de Aplicación                         │
      │   (NSG: Ingress 8080 desde Internet; Deny SSH 22; Egress AzureKeyVault) │
      │                                                                   │
      │         Virtual Machine Scale Set (VMSS - Ubuntu Jammy 22.04)     │
      │          • Multi-zona (Zonas 1, 2, 3)                             │
      │          • Autoscale: Min 2, Max 3, Desired 2                     │
      │          • Reparación automática de instancias (Action: Replace)  │
      │          • Sin IPs públicas directas / Sin SSH expuesto           │
      │          • Identidad Administrada asignada por el sistema         │
      │          • App Python nativa (urllib) que lee secretos de KV      │
      └──────────────────┬─────────────────────────────┬──────────────────┘
                         │ (Service Endpoint)          │
             [Azure Key Vault]                 [Azure Log Analytics]
         • RBAC habilitado                 • Auditoría AuditEvent de KV
         • Purge Protection activado       • Métricas de CPU y Alertas
         • Firewall por red e IP           • Destino de diagnósticos
```

---

## 2. Estructura del Repositorio

```text
caribeshop-infra/
├── .github/
│   └── workflows/
│       └── devsecops.yml        # Pipeline CI/CD: fmt, validate y Checkov bloqueante (D1)
├── terraform/                   # Definición como código de la infraestructura (IaC)
│   ├── scripts/
│   │   └── user_data.sh         # Script cloud-init reproducible para microservicio Python
│   ├── autoscale.tf             # Reglas de autoescalado reactivo con histéresis (E3)
│   ├── backend.tf               # Backend remoto en Azure Blob Storage (S1)
│   ├── key_vault.tf             # Azure Key Vault con RBAC y firewall por IP/VNet (S3, S4)
│   ├── load_balancer.tf         # Azure Standard Load Balancer con sonda dedicada (E2)
│   ├── main.tf                  # Resource Group principal
│   ├── monitoring.tf            # Log Analytics, Diagnostic Settings y Alerta CPU (S6, E5)
│   ├── network.tf               # Virtual Network y subred con Service Endpoint
│   ├── outputs.tf               # Salidas: IP pública, URLs y consulta KQL
│   ├── policy.tf                # Azure Policy preventiva con efecto Deny sobre SSH (S5)
│   ├── providers.tf             # Proveedores HashiCorp requeridos
│   ├── security.tf              # NSG con reglas de mínimo privilegio (S2)
│   ├── terraform.tfvars.example  # Plantilla de variables sin secretos reales
│   ├── variables.tf             # Declaración y tipado de variables
│   ├── versions.tf              # Fijación de versiones de Terraform y AzureRM
│   └── vmss.tf                  # VMSS multi-zona con reparación automática (E1, E4, D3)
├── tests/
│   └── locustfile.py            # Escenarios de prueba de carga y resiliencia (P1, P2)
├── evidencias/                  # Carpeta de reportes CSV/HTML de Locust y capturas
├── .gitignore                   # Exclusión estricta de tfstate y tfvars con secretos
└── README.md                    # Documentación del proyecto
```

---

## 3. Requisitos Previos

- [Azure CLI](https://learn.microsoft.com/es-es/cli/azure/install-azure-cli) instalado y autenticado (`az login`).
- [Terraform CLI](https://developer.hashicorp.com/terraform/install) (v1.5.0 o superior).
- [Python 3](https://www.python.org/) y [Locust](https://locust.io/) (`pip install locust`) para las pruebas de carga.

---

## 4. Variables de Configuración

Crea un archivo local `terraform/terraform.tfvars` a partir de `terraform/terraform.tfvars.example`:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

### Tabla de Variables

| Variable | Tipo | Descripción | Valor por Defecto |
| :--- | :--- | :--- | :--- |
| `project_name` | `string` | Nombre base para todos los recursos generados | `"caribeshop"` |
| `location` | `string` | Región de Azure (`brazil south`, `eastus`, etc.) | `"brazil south"` |
| `environment` | `string` | Entorno de despliegue (`dev`, `prod`) | `"dev"` |
| `zones` | `list(string)`| Zonas de disponibilidad para alta disponibilidad | `["1", "2", "3"]` |
| `admin_username` | `string` | Usuario administrativo Linux | `"azureuser"` |
| `ssh_public_key` | `string` | Clave pública SSH (opcional, evita requerir archivo local) | `""` |
| `vm_size` | `string` | Tamaño de cómputo para las VMs | `"Standard_D2s_v4"` |
| `min_instances` | `number` | Mínimo de instancias en Autoscale | `2` |
| `max_instances` | `number` | Máximo de instancias en Autoscale | `3` |
| `desired_instances`| `number`| Instancias deseadas en el arranque | `2` |
| `admin_ip` | `string` | IP pública CIDR del operador para firewall de Key Vault | `""` |
| `alert_email` | `string` | Correo donde se enviarán las alertas de Azure Monitor | `"admin@caribeshop.com"` |
| `app_secret_value` | `string` | Secreto a proteger en Azure Key Vault (sensible) | *(Requerido)* |

---

## 5. Guía de Despliegue y Destrucción

### Paso 1: Autenticación en Azure
```bash
az login
az account set --subscription "<ID_O_NOMBRE_DE_TU_SUSCRIPCION>"
```

### Paso 2: Inicializar Terraform
```bash
cd terraform

# Inicializar con el backend configurado:
terraform init

# Para pruebas locales o validación sintáctica sin backend:
terraform init -backend=false
```

### Paso 3: Validación y Planificación
```bash
terraform fmt -check
terraform validate
terraform plan -out=tfplan
```

### Paso 4: Despliegue
```bash
terraform apply tfplan
```
Al finalizar, Terraform mostrará los `outputs` con la IP pública del Load Balancer, las URLs de prueba y la consulta KQL.

### Paso 5: Destrucción de Recursos (Ahorro de Créditos)
> [!IMPORTANT]
> Para evitar consumir los créditos de la suscripción, destruye los recursos una vez finalizada la recolección de evidencias:
```bash
terraform destroy -auto-approve
```

---

## 6. Endpoints Disponibles en la Aplicación

- `http://<IP_LB>/`: Página principal de CaribeShop que muestra el hostname de la VM que atiende la petición, el estado del balanceador y la **huella de seguridad del secreto** (longitud y SHA-256 truncado) obtenido vía Managed Identity.
- `http://<IP_LB>/health`: Sonda de salud consumida por el Load Balancer. Retorna HTTP 200 en estado normal y HTTP 503 en caso de fallo inducido.
- `http://<IP_LB>/secret`: Endpoint JSON específico para verificar la integración con Key Vault (Requisito S3).
- `http://<IP_LB>/simulate-fail`: Endpoint de prueba para inducir fallo lógico en la instancia atendida (retornará 503 en salud para la prueba P2.1).
- `http://<IP_LB>/simulate-recover`: Restaura la salud de la instancia a HTTP 200.

---

## 7. Pruebas de Carga y Resiliencia (Locust)

### P1.1: Medir capacidad de una instancia
1. Configurar temporalmente en `terraform/terraform.tfvars`: `min_instances = 1`, `max_instances = 1`, `desired_instances = 1`.
2. Aplicar: `terraform apply -auto-approve`.
3. Lanzar Locust desde la raíz del proyecto:
```bash
locust -f tests/locustfile.py --host=http://<IP_LB>
```
4. Aumentar usuarios progresivamente hasta que el percentil 95 (p95) supere 1 segundo. Anotar los RPS máximos.

### P1.2: Prueba escalonada de 25 minutos (Scale-out / Scale-in)
1. Restaurar `min_instances = 2`, `max_instances = 3` y aplicar.
2. Ejecutar prueba guardando reportes en la carpeta `evidencias/`:
```bash
locust -f tests/locustfile.py --host=http://<IP_LB> --headless -u 150 -r 5 --run-time 25m --csv=evidencias/locust_escalonada --html=evidencias/locust_reporte.html
```

### P2.1: Prueba de Falla Lógica
1. Con carga constante de 40 usuarios en Locust, invocar:
```bash
curl http://<IP_LB>/simulate-fail
```
2. Medir cuánto tarda el Load Balancer en detectar el fallo (sonda /health con 503) y el porcentaje de errores observado.

---

## 7. Checklist de la Línea Base de Seguridad (Taller Integrador)

- [x] **S1: Estado en backend remoto y sin credenciales en Git**
  - Backend configurado en Azure Storage (`backend.tf`).
  - `.gitignore` robusto que excluye `.tfstate`, carpetas `.terraform/` y `.tfvars` con valores reales.
- [x] **S2: Red y mínimo privilegio**
  - VMSS sin IPs públicas directas en sus interfaces de red.
  - Subred protegida con NSG: Ingress bloqueado en puertos 22 (SSH) y 3389 (RDP).
  - Tráfico HTTP permitido hacia el puerto de la aplicación (8080) desde Internet vía Load Balancer.
  - Regla de salida (egress) configurada hacia `AzureKeyVault`.
- [x] **S3: Gestión segura de secretos con Managed Identity**
  - VMSS autenticado ante Key Vault mediante Identidad Administrada asignada por el sistema.
  - Key Vault con RBAC habilitado, Purge Protection activo, retención soft-delete y firewall de red.
  - Secreto con fecha de expiración configurada.
  - La aplicación jamás expone el valor del secreto; únicamente valida su lectura mostrando longitud y huella SHA-256 truncada.
- [x] **S4: Mínimo privilegio de roles RBAC**
  - La identidad del VMSS únicamente posee el rol `Key Vault Secrets User` limitado exclusivamente al ámbito del Key Vault.
- [x] **S5: Azure Policy preventiva con efecto Deny**
  - Política que rechaza cualquier intento de crear reglas de NSG que abran el puerto 22 SSH hacia Internet.
- [x] **S6: Observabilidad y diagnóstico**
  - Diagnostic Settings en Key Vault enviando eventos de auditoría (`AuditEvent`) a Log Analytics Workspace.
- [x] **E1: Alta disponibilidad multi-zona**
  - VMSS distribuido en zonas de disponibilidad (`zones = ["1", "2", "3"]`).
- [x] **E2: Balanceador de carga con sonda de salud dedicada**
  - Azure Load Balancer Standard con IP pública redundante de zona y sonda dedicada sobre `/health`.
- [x] **E3: Escalamiento automático con histéresis**
  - Reglas de autoscale basadas en CPU con umbrales diferenciados (> 70% scale-out, < 30% scale-in) y tiempos de enfriamiento (cooldown) definidos.
  - `ignore_changes = [instances]` configurado en el ciclo de vida del VMSS.
- [x] **E4: Reparación automática de instancias**
  - Bloque `automatic_instance_repair` habilitado con acción `Replace` y período de gracia.
- [x] **E5: Alertas proactivas de Azure Monitor**
  - Alerta de métrica de CPU sostenida (> 80%) configurada hacia un Action Group con notificación por correo.
- [x] **D1: DevSecOps en GitHub Actions**
  - Pipeline `.github/workflows/devsecops.yml` que corre en cada PR ejecutando `terraform fmt -check`, `validate` y análisis estático con `Checkov` bloqueante.
- [x] **D3: Configuración reproducible**
  - Configuración automatizada de la instancia sin intervención manual mediante `custom_data` (cloud-init).
